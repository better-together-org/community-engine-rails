# frozen_string_literal: true

module BetterTogether
  module Billing
    module Processors
      # Interac e-Transfer, sent from the buyer's bank to the seller's own email or phone.
      # The platform never holds the money. It exists in Canada, in Canadian dollars.
      class ETransfer < OfflineProcessorAdapter
        def processor_name = :etransfer

        def supported_countries = %w[CA]
        def supported_currencies = %w[CAD]

        def instruction_fields
          [InstructionField.new(name: :recipient_email, type: :email),
           InstructionField.new(name: :recipient_phone, type: :phone),
           InstructionField.new(name: :instructions, type: :text)]
        end

        # Buyers need somewhere to send it: an email or a phone number.
        def settings_errors(values)
          values = values.to_h.stringify_keys
          return {} if values['recipient_email'].to_s.strip.present? || values['recipient_phone'].to_s.strip.present?

          { 'recipient_email' => :recipient_missing }
        end
      end
    end
  end
end
