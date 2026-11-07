# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Billing
    RSpec.describe ProcessorAdapter do
      let(:adapter) { FakeAdapter.new }

      it_behaves_like 'a billing processor adapter'

      it 'rejects an object that does not inherit the contract' do
        expect { described_class.verify!(Object.new) }.to raise_error(described_class::ContractError, /must inherit/)
      end

      it 'rejects an adapter built for a different contract version' do
        stale = FakeAdapter.new
        allow(stale).to receive(:contract_version).and_return(described_class::CONTRACT_VERSION + 1)

        expect { described_class.verify!(stale) }.to raise_error(described_class::ContractError, /contract/)
      end

      it 'accepts an adapter registered under the name it reports' do
        expect(described_class.verify!(adapter, name: :fake)).to eq(adapter)
        expect(described_class.verify!(adapter, name: 'fake')).to eq(adapter)
      end

      it 'rejects an adapter registered under a name it does not report' do
        expect { described_class.verify!(adapter, name: :stripe) }
          .to raise_error(described_class::ContractError, /registered as stripe but reports processor_name fake/)
      end

      it 'documents a context for every capability method, so no call is made without a tenant' do
        keywords = described_class::CAPABILITY_METHODS.values.flat_map(&:values)

        expect(keywords).to all(include(:context))
      end

      describe 'settlement' do
        it 'treats a plain adapter as a remote, automatically renewing, fee-collecting processor' do
          expect(adapter).to have_attributes(settlement_kind: :remote, recurring_mode: :automatic, supported_countries: nil,
                                             fee_collectible?: true, instruction_fields: [])
        end

        it 'accepts a manual method that advertises offline_settlement' do
          manual = FakeAdapter.new(capabilities: %i[offline_settlement], settlement: :manual, countries: %w[CA])

          expect(described_class.verify!(manual)).to eq(manual)
          expect(manual).to have_attributes(recurring_mode: :manual, fee_collectible?: false)
        end

        it 'rejects offline_settlement on a remote method, and a manual method without it' do
          remote = FakeAdapter.new(capabilities: %i[offline_settlement])
          manual = FakeAdapter.new(capabilities: %i[checkout], settlement: :manual)

          expect { described_class.verify!(remote) }.to raise_error(described_class::ContractError, /go together/)
          expect { described_class.verify!(manual) }.to raise_error(described_class::ContractError, /go together/)
        end

        it 'rejects unknown settlement kinds, recurring modes and malformed countries' do
          expect { described_class.verify!(FakeAdapter.new(settlement: :barter)) }
            .to raise_error(described_class::ContractError, /unknown settlement_kind/)
          expect { described_class.verify!(FakeAdapter.new(countries: %w[Canada])) }
            .to raise_error(described_class::ContractError, /ISO 3166/)

          odd = FakeAdapter.new
          allow(odd).to receive(:recurring_mode).and_return(:sometimes)
          expect { described_class.verify!(odd) }.to raise_error(described_class::ContractError, /unknown recurring_mode/)
        end

        it 'fails closed on the new capability methods' do
          bare = Class.new(described_class) { def processor_name = :bare }.new

          %i[refund transfer instructions_for].each do |name|
            expect { bare.public_send(name) }.to raise_error(described_class::UnsupportedCapabilityError)
          end
        end

        it 'documents context: for the new capability methods' do
          methods = described_class::CAPABILITY_METHODS.slice(:refunds, :transfers, :offline_settlement).values.flat_map(&:values)

          expect(methods).to all(include(:context))
        end
      end

      it 'fails closed on abstract and unsupported methods' do
        bare = Class.new(described_class) { def processor_name = :bare }.new

        expect { bare.sanitize_payload({}) }.to raise_error(NotImplementedError)
        expect { bare.create_portal_session(owner: nil, return_url: 'x') }.to raise_error(described_class::UnsupportedCapabilityError)
        expect(bare.supports?(:checkout)).to be false
      end
    end
  end
end
