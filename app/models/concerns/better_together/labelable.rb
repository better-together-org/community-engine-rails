# frozen_string_literal: true

module BetterTogether
  module Labelable # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      # Add translates :custom_label for translatable custom labels
      # Validate presence and inclusion of label
      validates :label, presence: true, inclusion: { in: label_keys }
    end

    class_methods do
      def extra_permitted_attributes
        super + [:label]
      end

      # Each including model must define a LABELS constant as an array of symbols or strings
      def label_keys
        self::LABELS.map(&:to_s)
      end

      # Returns an array of [display_name, stored_value] pairs for form select helpers
      def label_options
        self::LABELS.map do |label|
          [
            I18n.t("#{model_name.collection.gsub('/', '.')}.labels.#{label}"), # Display name from I18n
            label.to_s # Stored value
          ]
        end
      end
    end

    def display_label
      I18n.t("#{self.class.model_name.collection.gsub('/', '.')}.labels.#{label}")
    end
  end
end
