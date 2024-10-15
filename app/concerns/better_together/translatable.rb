# frozen_string_literal: true

module BetterTogether
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

        return localized_attributes unless respond_to?(:mobility_attributes)

        # This method returns symbols suitable for strong parameters and attribute access in Rails controllers.
        mobility_attributes.map do |attribute|
          I18n.available_locales.map do |locale|
            "#{attribute}_#{locale}".to_sym
          end
        end.flatten
      end

      def self.localized_attribute_names_for_elasticsearch
        # This method returns strings specifically for Elasticsearch indexing.
        localized_attributes = []

        return localized_attributes unless respond_to?(:mobility_attributes)

        mobility_attributes.map do |attribute|
          I18n.available_locales.map do |locale|
            "#{attribute}_#{locale}"
          end
        end.flatten
      end
    end
  end
end
