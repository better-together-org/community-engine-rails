# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Billing
    RSpec.describe Configuration do
      let(:full_env) do
        { 'PAY_BUSINESS_NAME' => 'Example Co-op', 'PAY_BUSINESS_ADDRESS' => '1 Main St',
          'PAY_SUPPORT_EMAIL' => 'support@example.org' }
      end

      it 'is ready when the business identity keys are present' do
        expect(described_class.ready?(full_env)).to be true
      end

      it 'fails closed and names the missing keys; blanks count as missing' do
        env = full_env.merge('PAY_SUPPORT_EMAIL' => '  ').except('PAY_BUSINESS_NAME')

        expect(described_class.ready?(env)).to be false
        expect(described_class.missing_keys(env)).to contain_exactly('PAY_BUSINESS_NAME', 'PAY_SUPPORT_EMAIL')
      end

      it 'has no built-in currency or country' do
        expect(described_class.default_currency({})).to be_nil
        expect(described_class.default_country({})).to be_nil
      end

      it 'upcases configured currency and country' do
        env = { 'BT_BILLING_DEFAULT_CURRENCY' => 'usd', 'BT_BILLING_DEFAULT_COUNTRY' => 'us' }

        expect(described_class.default_currency(env)).to eq('USD')
        expect(described_class.default_country(env)).to eq('US')
      end

      it 'raises when a feature requires a country that is not configured' do
        expect { described_class.require_default_country!({}) }
          .to raise_error(Configuration::MissingConfigurationError, /BT_BILLING_DEFAULT_COUNTRY/)
      end

      it 'logs one warning listing missing keys and stays silent when ready' do
        logger = instance_double(Logger, warn: nil)
        stub_const('ENV', ENV.to_hash.except('PAY_BUSINESS_NAME'))

        described_class.log_missing!(logger)

        expect(logger).to have_received(:warn).with(/PAY_BUSINESS_NAME/)
      end
    end
  end
end
