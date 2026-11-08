# frozen_string_literal: true

module BetterTogether
  module Billing
    # One field a seller fills in so buyers know how to pay outside the platform (an
    # e-transfer address, a cheque payee). An offline adapter declares these through
    # `instruction_fields`; core builds the settings form from them and stores the values
    # encrypted. Values are always sensitive: they are shown only on the buyer's own order.
    class InstructionField < Data.define(:name, :type, :required) # rubocop:disable Style/DataInheritance
      TYPES = %i[string text email phone].freeze

      def initialize(name:, type: :string, required: false)
        raise ArgumentError, "unknown instruction field type #{type.inspect}" unless TYPES.include?(type.to_sym)

        super(name: name.to_sym, type: type.to_sym, required: required ? true : false)
      end

      def required? = required
    end
  end
end
