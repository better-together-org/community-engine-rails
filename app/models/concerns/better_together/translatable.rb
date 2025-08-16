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
        super + localized_attribute_list
      end
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

    private

    # Returns the first non-blank translation value for the given translated
    # attribute across available locales, considering unsaved changes.
    # For Action Text backends, compares on plain text.
    def first_present_translation_of(attr)
      locales = begin
        if defined?(Mobility) && Mobility.respond_to?(:available_locales)
          Mobility.available_locales.presence || I18n.available_locales
        else
          I18n.available_locales
        end
      rescue StandardError
        I18n.available_locales
      end

      Array(locales).each do |loc|
        val = nil
        if defined?(Mobility)
          Mobility.with_locale(loc) { val = public_send(attr) }
        else
          val = public_send(attr)
        end

        # Normalize ActionText rich text to plain text for presence check
        val = val.to_plain_text if val.respond_to?(:to_plain_text)

        return val if val.present?
      end

      # Fallback: check raw locale-suffixed columns/associations (e.g., name_en)
      Array(I18n.available_locales).each do |loc|
        method = :"#{attr}_#{loc}"
        next unless respond_to?(method)

        val = public_send(method)
        val = val.to_plain_text if val.respond_to?(:to_plain_text)
        val = val.to_s if !val.is_a?(String) && val.respond_to?(:to_s)
        return val if val.present?
      end

      nil
    end
  end
end
