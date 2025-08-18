# frozen_string_literal: true

module BetterTogether
  # Concern that when included makes the model act as an identity
  module Translatable
    extend ActiveSupport::Concern

    included do
      extend Mobility

      scope :with_translations, lambda {
        include_list = []
        include_list << :string_translations if model.instance_methods.include?(:string_translations)
        include_list << :text_translations if model.instance_methods.include?(:text_translations)
        include_list << :rich_text_translations if model.instance_methods.include?(:rich_text_translations)

        includes(include_list)
      }

      def self.localized_attribute_list
        localized_attributes = []

        return localized_attributes unless respond_to? :mobility_attributes

        localized_attributes = mobility_attributes.map do |attribute|
          I18n.available_locales.map do |locale|
            :"#{attribute}_#{locale}"
          end
        end

        localized_attributes.flatten
      end

      def self.extra_permitted_attributes
        # Permit both locale-specific and base attribute names so callers can
        # submit either `name`/`description` for current locale or
        # `name_en`/`description_en` for explicit locales.
        base_attrs = respond_to?(:mobility_attributes) ? mobility_attributes.map(&:to_sym) : []
        super + localized_attribute_list + base_attrs
      end

      # Make presence validators on translated attributes pass if any in-memory
      # localized value is present (including unsaved changes). This preserves
      # required_label behavior while avoiding false negatives before persistence.
      def read_attribute_for_validation(attr)
        if self.class.respond_to?(:mobility_attributes) &&
           self.class.mobility_attributes.map(&:to_sym).include?(attr.to_sym)
          return first_present_translation_of(attr)
        end

        super
      end
    end

    private

    # Returns the first non-blank translation value for the given translated
    # attribute across available locales, considering unsaved changes.
    # For Action Text backends, compares on plain text.
    def first_present_translation_of(attr)
      return nil unless self.class.respond_to?(:localized_attribute_list)

      # 0) Try direct, locale-suffixed accessors first to capture unsaved
      #    in-memory writes (e.g., description_en) before association objects exist.
      if respond_to?(:mobility_attributes)
        I18n.available_locales.each do |loc|
          meth = "#{attr}_#{loc}"
          next unless respond_to?(meth)

          begin
            val = public_send(meth)
            val = val.to_plain_text if val.respond_to?(:to_plain_text)
            return val if val.present?
          rescue StandardError
            next
          end
        end
      end

      # Check string translations
      if respond_to?(:string_translations)
        matches = string_translations.select { |translation| translation.key == attr.to_s }
        match = matches.find { |translation| translation.value.present? }
        return match.value if match
      end

      # Only check text translations if no value found in string translations
      if respond_to?(:text_translations)
        matches = text_translations.select { |translation| translation.key == attr.to_s }
        match = matches.find { |translation| translation.value.present? }
        return match.value if match
      end

      # Only check rich text translations if no value found in previous checks
      if respond_to?(:rich_text_translations)
        matches = rich_text_translations.select { |translation| translation.name == attr.to_s }
        match = matches.find do |translation|
          val = translation.body
          val = val.to_plain_text if val.respond_to?(:to_plain_text)
          val.present?
        end
        if match
          val = match.body
          val = val.to_plain_text if val.respond_to?(:to_plain_text)
          return val
        end
      end

      nil
    end
  end
end
