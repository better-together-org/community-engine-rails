# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Billing do
    include_context 'with clean billing processors'

    let(:host_platform) { configure_host_platform }
    let(:other_platform) { create(:better_together_platform) }
    let(:env) do
      { 'BT_BILLING_ENABLED' => 'true', 'PAY_BUSINESS_NAME' => 'Example Co-op',
        'PAY_BUSINESS_ADDRESS' => '1 Main St', 'PAY_SUPPORT_EMAIL' => 'support@example.org' }
    end

    it 'has no processor until an extension registers one' do
      expect(described_class.processor_names).to be_empty
      expect(described_class.processor_adapter).to be_nil
      expect(described_class.enabled?(host_platform, env:)).to be false
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

    it 'refuses an adapter that reports a different name than it was registered under' do
      described_class.register_processor(:stripe_eu, -> { Billing::FakeAdapter.new })

      expect { described_class.processor_adapter(:stripe_eu) }
        .to raise_error(Billing::ProcessorAdapter::ContractError, /registered as stripe_eu but reports processor_name fake/)
    end

    describe '.enabled?' do
      before { described_class.register_processor(:fake, -> { Billing::FakeAdapter.new }) }

      it 'is on for the host platform only with the flag, host identity and a processor' do
        expect(described_class.enabled?(host_platform, env:)).to be true
        expect(described_class.enabled?(host_platform, env: env.merge('BT_BILLING_ENABLED' => 'false'))).to be false
        expect(described_class.enabled?(host_platform, env: env.except('PAY_SUPPORT_EMAIL'))).to be false
      end

      it 'is off for a platform that has no processor context of its own' do
        expect(described_class.enabled?(other_platform, env:)).to be false
      end

      it 'is off when there is no platform at all, as in a job or console with no tenant in hand' do
        expect(described_class.enabled?(nil, env:)).to be false
      end

      it 'defaults to the current request platform' do
        Current.platform = host_platform

        expect(described_class.enabled?(env:)).to be true
      ensure
        Current.platform = nil
      end
    end
  end
end
