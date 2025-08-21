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
    end
  end
end
