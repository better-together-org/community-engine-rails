# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Base controller for Joatu resources, adds notification mark-as-read helpers
    class JoatuController < BetterTogether::FriendlyResourceController
      include BetterTogether::NotificationReadable

      # Normalize translated params so base keys are populated for current locale.
      # This helps presence validations (esp. for ActionText) during create/update
      # when forms submit locale-suffixed fields like `description_en`.
      def resource_params # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
        rp = super
        return rp unless rp.is_a?(ActionController::Parameters) || rp.is_a?(Hash)

        locale = I18n.locale.to_s
        %w[name description].each do |attr|
          localized_key_sym = :"#{attr}_#{locale}"
          localized_key_str = "#{attr}_#{locale}"
          next if rp.key?(attr) && rp[attr].present?

          val = rp[localized_key_sym] || rp[localized_key_str]
          rp[attr] = val if val.present?
        end

        rp
      end

      private

      # Safely resolve a source_type parameter to a valid Joatu model class
      # Allow-list only classes that include the Exchange concern to prevent security issues
      def joatu_source_class(source_type_param)
        param_type = source_type_param.to_s

        # Dynamically build allow-list from models that include the Exchange concern
        valid_source_types = BetterTogether::Joatu::Exchange.included_in_models
        
        valid_source_types.find { |klass| klass.to_s == param_type }
      end
    end
  end
end
