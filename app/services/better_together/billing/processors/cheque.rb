# frozen_string_literal: true

module BetterTogether
  module Billing
    module Processors
      # A cheque made out to the seller. Only the payee name and where to send or drop it
      # off are kept: never an account, transit or routing number.
      #
      # A cheque can bounce, so the seller may start the buyer's access when it is received
      # or only once it has cleared. Clearing is the safe default.
      class Cheque < OfflineProcessorAdapter
        def processor_name = :cheque

        def grant_on_options = %w[cleared received]

        def instruction_fields
          [InstructionField.new(name: :payee_name, type: :string, required: true),
           InstructionField.new(name: :address, type: :text, required: true),
           InstructionField.new(name: :instructions, type: :text)]
        end
      end
    end
  end
end
