# frozen_string_literal: true

# Mobility Attachments backend
# This backend dynamically defines per-attribute, per-locale attachment accessors.
# It is intentionally large because it generates many methods on host models.
#
# NOTE: This file performs a fair amount of dynamic method generation to wire
# translated ActiveStorage attachment accessors on host models. That design
# concentrates complexity into a single, intentionally large implementation.
# To keep the implementation clear and avoid noisy metric offenses from
# RuboCop (which are not helpful for this dynamic code), we disable a small
# set of metric cops for this file. Please don't re-enable them here unless
# you refactor into smaller, testable helpers.
# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/BlockLength, Metrics/BlockNesting, Layout/LineLength

# Documentation: Mobility::Backends - namespace for Mobility storage backends.
require 'mobility/backend'
module Mobility
  # Namespace for Mobility storage backends.
  # Backends implement storage and retrieval strategies for translated data.
  module Backends
    # Backend that provides translated attachment accessors.
    class AttachmentsBackend
      include Mobility::Backend

      # Shared implementation for applying the attachment translation setup to a model.
      # Extracted so external shims (e.g. translates_attached) can reuse the logic.
      def self.apply_to(model_class, attributes, options)
        # ensure class_attribute exists to track configured attachments
        unless model_class.respond_to?(:mobility_translated_attachments)
          model_class.class_attribute :mobility_translated_attachments, instance_predicate: false,
                                                                        instance_accessor: false
          model_class.mobility_translated_attachments = {}
        end

        attributes.each do |attr_name|
          name = attr_name.to_s
          model_class.mobility_translated_attachments = model_class.mobility_translated_attachments.merge(name.to_sym => options)

          # Process options: support :content_type (array/regex) and :presence (boolean)
          content_types = options[:content_type]
          require_presence = options[:presence]

          if content_types || require_presence
            # inject validation helpers into model
            model_class.validate do
              att = ActiveStorage::Attachment.where(record: self, name: name, locale: Mobility.locale.to_s).first
              errors.add(name.to_sym, :blank) if require_presence && att.nil?
              if att && content_types
                ct = att.blob&.content_type
                unless Array(content_types).any? do |pat|
                  if pat.is_a?(Regexp)
                    pat.match?(ct)
                  else
                    pat == ct
                  end
                end
                  errors.add(name.to_sym, :invalid, message: 'invalid content type')
                end
              end
            end
          end

          # define an association that returns the attachment for current Mobility.locale
          assoc_name = "#{name}_attachment"

          # define has_many for all locales (admin management)
          model_class.has_many(:"#{name}_attachments_all", -> { where(name: name) },
                               class_name: 'ActiveStorage::Attachment', as: :record, inverse_of: :record, dependent: :destroy)

          # define a has_one for current locale using a lambda scope that uses Mobility.locale
          model_class.has_one(assoc_name.to_sym, -> { where(name: name, locale: Mobility.locale.to_s) },
                              class_name: 'ActiveStorage::Attachment', as: :record, inverse_of: :record, autosave: true, dependent: :destroy)

          # define eager-load scope
          scope_name = "with_#{name}_attachment"
          model_class.singleton_class.instance_eval do
            define_method(scope_name) do
              includes(assoc_name.to_sym => { blob_attachment: :blob })
            end
          end

          # define per-locale accessors using available locales
          locales = if defined?(Mobility) && Mobility.respond_to?(:available_locales)
                      Mobility.available_locales.map(&:to_sym)
                    else
                      I18n.available_locales.map(&:to_sym)
                    end

          locales.each do |locale|
            accessor = Mobility.normalize_locale_accessor(name, locale)

            # getter
            model_class.define_method(accessor) do |fallback: true|
              # prefer cached association when present
              if association_cached?(assoc_name)
                att = public_send(assoc_name)
                return att if att && att.locale.to_s == locale.to_s
              end

              att = ActiveStorage::Attachment.where(record: self, name: name, locale: locale.to_s).first
              if att.nil? && fallback
                att = ActiveStorage::Attachment.where(record: self, name: name, locale: I18n.default_locale.to_s).first
              end
              att
            end

            # predicate
            model_class.define_method("#{accessor}?") do
              send(accessor, fallback: false).present?
            end

            # writer - create or update an attachment row via the association so `record_id` is always set
            model_class.define_method("#{accessor}=") do |attachable|
              attachments_assoc = public_send("#{name}_attachments_all")
              existing = attachments_assoc.find_by(locale: locale.to_s)

              if attachable.nil?
                if existing
                  existing.purge
                  existing.destroy
                end
                next
              end

              # Determine blob from various attachable shapes
              blob = if attachable.is_a?(ActiveStorage::Blob)
                       attachable
                     elsif attachable.respond_to?(:blob) && attachable.blob
                       attachable.blob
                     elsif attachable.is_a?(Hash) && attachable[:io]
                       ActiveStorage::Blob.create_and_upload!(io: attachable[:io],
                                                              filename: attachable[:filename] || 'upload', content_type: attachable[:content_type])
                     elsif attachable.respond_to?(:read)
                       filename = attachable.respond_to?(:original_filename) ? attachable.original_filename : 'upload'
                       content_type = attachable.respond_to?(:content_type) ? attachable.content_type : nil
                       ActiveStorage::Blob.create_and_upload!(io: attachable, filename: filename,
                                                              content_type: content_type)
                     else
                       # Fallback: try to coerce via to_path (file path) or raise for unsupported types
                       unless attachable.respond_to?(:to_path)
                         raise ArgumentError, "Unsupported attachable type: #{attachable.class}"
                       end

                       file = File.open(attachable.to_path, 'rb')
                       ActiveStorage::Blob.create_and_upload!(io: file, filename: File.basename(attachable.to_path))

                     end

              if existing
                existing.update!(blob: blob)
              else
                # Use the association create! so ActiveRecord sets record_id correctly
                attachments_assoc.create!(blob: blob, name: name, locale: locale.to_s)
              end
            end

            # url helper
            model_class.define_method("#{accessor}_url") do |variant: nil, host: nil, fallback: true|
              att = send(accessor, fallback: fallback)
              return unless att&.blob

              if variant
                Rails.application.routes.url_helpers.rails_representation_url(att.blob.variant(variant).processed,
                                                                              host: host)
              else
                Rails.application.routes.url_helpers.rails_blob_url(att.blob, host: host)
              end
            end
          end

          # Non-locale delegating accessors (e.g. hero_image, hero_image=)
          # These delegate to the accessor for the current Mobility.locale.
          model_class.define_method(name) do |fallback: true|
            accessor = Mobility.normalize_locale_accessor(name, Mobility.locale)
            send(accessor, fallback: fallback)
          end

          model_class.define_method("#{name}=") do |attachable|
            accessor = Mobility.normalize_locale_accessor(name, Mobility.locale)
            send("#{accessor}=", attachable)
          end

          model_class.define_method("#{name}?") do
            accessor = Mobility.normalize_locale_accessor(name, Mobility.locale)
            send("#{accessor}?")
          end

          model_class.define_method("#{name}_url") do |variant: nil, host: nil, fallback: true|
            accessor = Mobility.normalize_locale_accessor(name, Mobility.locale)
            send("#{accessor}_url", variant: variant, host: host, fallback: fallback)
          end

          # Define non-locale delegating accessors that work with the current
          # Mobility.locale so that models expose the same API as non-localized
          # attachments (e.g. `hero_image`, `hero_image=`, `hero_image?`, `hero_image_url`).
          model_class.define_method(name) do |fallback: true|
            locale_accessor = Mobility.normalize_locale_accessor(name, Mobility.locale)
            send(locale_accessor, fallback: fallback)
          end

          model_class.define_method("#{name}=") do |attachable|
            locale_writer = "#{Mobility.normalize_locale_accessor(name, Mobility.locale)}="
            send(locale_writer, attachable)
          end

          model_class.define_method("#{name}?") do
            locale_pred = "#{Mobility.normalize_locale_accessor(name, Mobility.locale)}?"
            send(locale_pred)
          end

          model_class.define_method("#{name}_url") do |**opts|
            locale_url = "#{Mobility.normalize_locale_accessor(name, Mobility.locale)}_url"
            send(locale_url, **opts)
          end

          # Ensure ActiveStorage callback code that expects attachment_reflections[name]
          # to exist does not trip over nil. We inject a small wrapper on the model
          # that merges synthetic reflections for each translated attachment name.
          next if model_class.singleton_class.instance_variable_defined?(:@_mobility_attachment_reflections_wrapped)

          orig = begin
            model_class.method(:attachment_reflections)
          rescue StandardError
            nil
          end
          model_class.define_singleton_method(:attachment_reflections) do
            base = orig ? orig.call : {}
            base = base.dup
            if respond_to?(:mobility_translated_attachments) && mobility_translated_attachments
              mobility_translated_attachments.each_key do |k|
                key = k.to_s
                unless base[key]
                  # Minimal reflection-like object expected by ActiveStorage
                  base[key] = Struct.new(:options, :named_variants).new({}, {})
                end
              end
            end
            base
          end
          model_class.singleton_class.instance_variable_set(:@_mobility_attachment_reflections_wrapped, true)
        end
      end

      # Track configured translated attachments on the model via Mobility.setup
      setup do |attributes, options|
        self.class.apply_to(model_class, attributes, options)
      end

      # read/write are intentionally not implemented here; per-locale accessors
      # are generated directly on the host model via the setup block above.
    end

    # NOTE: registration is performed by the Mobility initializer to ensure
    # Mobility's API is available at registration time.
    Mobility::Backends.const_set(:Attachments, AttachmentsBackend)
  end
end

# Re-enable metric cops disabled at the top of this file.
# Re-enable metric cops disabled at the top of this file.
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
# rubocop:enable Metrics/BlockLength, Metrics/BlockNesting, Layout/LineLength
