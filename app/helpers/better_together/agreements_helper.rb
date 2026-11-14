# frozen_string_literal: true

module BetterTogether
  # Helpers for Agreements
  module AgreementsHelper
    def agreement_acceptance_param_name(agreement_or_identifier)
      identifier = if agreement_or_identifier.respond_to?(:identifier)
                     agreement_or_identifier.identifier.to_s
                   else
                     agreement_or_identifier.to_s
                   end

      identifier.end_with?('_agreement') ? identifier : "#{identifier}_agreement"
    end

    def agreement_acceptance_checkbox_id(agreement_or_identifier)
      "#{agreement_acceptance_param_name(agreement_or_identifier)}_checkbox"
    end

    def missing_publishing_agreement_error_for?(object)
      object.errors.full_messages.include?(BetterTogether::PublicVisibilityGate.error_message_for(:missing_publishing_agreement))
    end
  end
end
