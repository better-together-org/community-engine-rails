# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Content::Block (STI base)
      #
      # All 19 block types share this resource.  The :block_type attribute
      # carries the STI discriminator (Rails :type renamed to avoid the
      # reserved-word clash in JSONAPI::Resources).
      #
      # Translatable attributes (heading, content, markdown_source, …) are
      # surfaced through the :translations virtual attribute as a nested hash:
      #
      #   { "en" => { "heading" => "…", "cta_text" => "…" },
      #     "fr" => { … } }
      #
      # JSONB columns (:content_data, :css_settings, :accessibility_attributes,
      # :data_attributes) are exposed whole — no per-type field explosion.
      class ContentBlockResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Content::Block'

        # STI discriminator — exposed as :block_type to avoid Rails reserved :type
        attribute :block_type

        # Standard shared attributes
        attributes :identifier, :privacy, :visible, :protected

        # JSONB columns exposed as opaque objects
        attribute :css_settings
        attribute :content_data
        attribute :accessibility_attributes
        attribute :data_attributes

        # Translatable attributes across all locales
        # Represented as { locale_string => { attr_name => value } }
        attribute :translations

        # Relationships
        has_many :page_blocks, class_name: 'PageBlock'

        # Filters
        filter :block_type
        filter :privacy
        filter :identifier

        # ── Attribute readers ────────────────────────────────────────────────

        def block_type
          @model.type
        end

        def translations
          locales = I18n.available_locales
          translatable = @model.class.respond_to?(:mobility_attributes) ? @model.class.mobility_attributes : []
          return {} if translatable.empty?

          locales.each_with_object({}) do |locale, hash|
            hash[locale.to_s] = translatable.each_with_object({}) do |attr, attrs|
              attrs[attr.to_s] = I18n.with_locale(locale) { @model.public_send(attr) }
            rescue StandardError
              nil
            end
          end
        end

        def css_settings
          @model.css_settings
        end

        def content_data
          @model.content_data
        end

        def accessibility_attributes
          @model.respond_to?(:accessibility_attributes) ? @model.accessibility_attributes : {}
        end

        def data_attributes
          @model.respond_to?(:data_attributes) ? @model.data_attributes : {}
        end

        # ── Write field lists ────────────────────────────────────────────────

        def self.creatable_fields(_context)
          %i[block_type identifier privacy visible
             css_settings content_data accessibility_attributes data_attributes
             translations]
        end

        def self.updatable_fields(_context)
          %i[identifier privacy visible
             css_settings content_data accessibility_attributes data_attributes
             translations]
        end

        # ── Custom attribute assignment to handle STI type + translations ──────

        def _assign_attributes(attrs) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          translations_data = attrs.delete(:translations) || {}
          block_type_val    = attrs.delete(:block_type)

          # Set STI type before assigning other attributes on new records.
          # Rails persists the raw type string; the correct subclass is returned
          # on subsequent finders automatically.
          if block_type_val.present? && @model.new_record?
            full_type = resolve_block_class_name(block_type_val)
            @model.type = full_type if full_type
          end

          result = super

          apply_translations(translations_data)

          result
        end

        private

        def apply_translations(translations_data)
          translations_data.each do |locale, locale_attrs|
            next unless locale_attrs.is_a?(Hash)

            I18n.with_locale(locale) do
              locale_attrs.each do |attr, value|
                setter = :"#{attr}="
                @model.public_send(setter, value) if @model.respond_to?(setter)
              rescue StandardError
                nil
              end
            end
          end
        end

        def resolve_block_class_name(type_input)
          # Accept short name ("Hero"), module-scoped name ("Content::Hero"),
          # or fully-qualified name ("BetterTogether::Content::Hero").
          BetterTogether::Content::Block.descendants.find do |klass|
            klass.name == type_input ||
              klass.name.demodulize == type_input ||
              klass.name.sub('BetterTogether::', '') == type_input
          end&.name
        end
      end
    end
  end
end
