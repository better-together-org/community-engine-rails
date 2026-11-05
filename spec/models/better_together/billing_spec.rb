# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Billing do
    around do |example|
      BetterTogether.clear_adapters!(described_class::ADAPTER_GROUP)
      example.run
    ensure
      BetterTogether.clear_adapters!(described_class::ADAPTER_GROUP)
    end

    let(:env) do
      { 'BT_BILLING_ENABLED' => 'true', 'PAY_BUSINESS_NAME' => 'Example Co-op',
        'PAY_BUSINESS_ADDRESS' => '1 Main St', 'PAY_SUPPORT_EMAIL' => 'support@example.org' }
    end

    it 'has no processor until an extension registers one' do
      expect(described_class.processor_names).to be_empty
      expect(described_class.processor_adapter).to be_nil
      expect(described_class.enabled?(env)).to be false
    end

    it 'resolves a registered processor by name and verifies the contract' do
      described_class.register_processor(:fake, -> { Billing::FakeAdapter.new })

      expect(described_class.processor_names).to eq([:fake])
      expect(described_class.processor_adapter(:fake)).to be_a(Billing::FakeAdapter)
      expect(described_class.processor_adapter).to be_a(Billing::FakeAdapter)
    end

    it 'refuses a registered factory that returns a non-conforming adapter' do
      described_class.register_processor(:bad, -> { Object.new })

      expect { described_class.processor_adapter(:bad) }.to raise_error(Billing::ProcessorAdapter::ContractError)
    end

    it 'is enabled only with the flag, host identity and a processor' do
      described_class.register_processor(:fake, -> { Billing::FakeAdapter.new })

      expect(described_class.enabled?(env)).to be true
      expect(described_class.enabled?(env.merge('BT_BILLING_ENABLED' => 'false'))).to be false
      expect(described_class.enabled?(env.except('PAY_SUPPORT_EMAIL'))).to be false
    end
  end
end
