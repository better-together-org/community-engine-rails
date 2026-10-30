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

      it 'fails closed on abstract and unsupported methods' do
        bare = Class.new(described_class) { def processor_name = :bare }.new

        expect { bare.sanitize_payload({}) }.to raise_error(NotImplementedError)
        expect { bare.create_portal_session(owner: nil, return_url: 'x') }.to raise_error(described_class::UnsupportedCapabilityError)
        expect(bare.supports?(:checkout)).to be false
      end
    end
  end
end
