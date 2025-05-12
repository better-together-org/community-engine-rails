# frozen_string_literal: true

module BetterTogether
  module Labelable # rubocop:todo Style/Documentation
    extend ActiveSupport::Concern

    included do
      # Add translates :custom_label for translatable custom labels
      # Validate presence and inclusion of label
      validates :label, presence: true
    end

    class_methods do
      def extra_permitted_attributes
        super + [:label, :select_label, :text_label]
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
      return label if label.present? && !self.class::LABELS.include?(label.to_sym)

      I18n.t("#{self.class.model_name.collection.gsub('/', '.')}.labels.#{label}")
    end

    def select_label
      return label if label.present? && self.class::LABELS.include?(label.to_sym)

      'other'
    end

    def select_label= arg
      return if arg == 'other'

      self.label = arg
    end

    def text_label
      return nil if label.present? && self.class::LABELS.include?(label.to_sym)

      label
    end

    def text_label= arg
      return if arg.present? && self.class::LABELS.include?(arg.to_sym)

      self.label = arg
    end
  end
end
