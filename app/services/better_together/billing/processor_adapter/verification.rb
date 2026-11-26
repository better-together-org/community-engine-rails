# frozen_string_literal: true

module BetterTogether
  module Billing
    class ProcessorAdapter
      # Class-level checks that an adapter honours the contract (see ProcessorAdapter.verify!).
      module Verification
        # Checks an adapter is usable: it inherits this contract, implements the
        # supported contract version, and (when `name` is the name it was registered
        # under) reports that same processor name, so events and plans stored under
        # the registered name always resolve back to the adapter that handles them.
        def verify!(adapter, name: nil)
          raise ContractError, "#{adapter.class} must inherit #{ProcessorAdapter.name}" unless adapter.is_a?(ProcessorAdapter)

          verify_contract_version!(adapter)
          if name && adapter.processor_name.to_s != name.to_s
            raise ContractError, "#{adapter.class} is registered as #{name} but reports processor_name #{adapter.processor_name}"
          end

          verify_settlement!(adapter)

          adapter
        end

        private

        def verify_contract_version!(adapter)
          return if SUPPORTED_CONTRACT_VERSIONS.include?(adapter.contract_version)

          raise ContractError,
                "#{adapter.class} implements contract #{adapter.contract_version}, core supports #{SUPPORTED_CONTRACT_VERSIONS.join(' and ')}"
        end

        def verify_settlement!(adapter)
          kind = adapter.settlement_kind
          raise ContractError, "#{adapter.class} has unknown settlement_kind #{kind.inspect}" unless SETTLEMENT_KINDS.include?(kind)

          mode = adapter.recurring_mode
          raise ContractError, "#{adapter.class} has unknown recurring_mode #{mode.inspect}" unless RECURRING_MODES.include?(mode)

          if adapter.supports?(:offline_settlement) != (kind == :manual)
            raise ContractError, "#{adapter.class}: the offline_settlement capability and settlement_kind :manual go together"
          end

          verify_countries!(adapter)
        end

        def verify_countries!(adapter)
          countries = adapter.supported_countries
          return if countries.nil? || (countries.is_a?(Array) && countries.all? { |code| code.to_s.match?(/\A[A-Z]{2}\z/) })

          raise ContractError, "#{adapter.class}#supported_countries must be nil or a list of ISO 3166 alpha-2 codes"
        end
      end
    end
  end
end
