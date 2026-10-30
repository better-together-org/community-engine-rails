# frozen_string_literal: true

module BetterTogether
  module Billing
    module Processors
      # Cash, handed over in person. The seller says where and when.
      class Cash < OfflineProcessorAdapter
        def processor_name = :cash

        def instruction_fields
          [InstructionField.new(name: :instructions, type: :text, required: true)]
        end
      end
    end
  end
end
