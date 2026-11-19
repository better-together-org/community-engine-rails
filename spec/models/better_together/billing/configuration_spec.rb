# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Billing
    RSpec.describe Configuration do
      include_context 'with clean billing processors'

      let(:full_env) do
        { 'PAY_BUSINESS_NAME' => 'Example Co-op', 'PAY_BUSINESS_ADDRESS' => '1 Main St',
          'PAY_SUPPORT_EMAIL' => 'support@example.org' }
      end

      def enable_method(platform, method = 'cash', **attrs)
        platform.billing_processor_settings.create!({ processor: method, enabled: true, acknowledge: true,
                                                      settings: { 'instructions' => 'At the hall' } }.merge(attrs))
      end

      it 'is ready when the business identity keys are present' do
        expect(described_class.ready?(full_env)).to be true
      end

      it 'fails closed and names the missing keys; blanks count as missing' do
        env = full_env.merge('PAY_SUPPORT_EMAIL' => '  ').except('PAY_BUSINESS_NAME')

        expect(described_class.ready?(env)).to be false
        expect(described_class.missing_keys(env)).to contain_exactly('PAY_BUSINESS_NAME', 'PAY_SUPPORT_EMAIL')
      end

      it 'counts the default from address as the support email when none is set', :aggregate_failures do
        without_support = full_env.except('PAY_SUPPORT_EMAIL')

        expect(described_class.missing_keys(without_support)).to eq(['PAY_SUPPORT_EMAIL'])
        expect(described_class.ready?(without_support.merge('DEFAULT_FROM_EMAIL' => 'Hello <hello@example.org>'))).to be true
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

      it 'caps one steward credit grant, 1000 in major units unless configured' do
        expect(described_class.max_credit_grant_minor('USD', {})).to eq(100_000)
        expect(described_class.max_credit_grant_minor('JPY', { 'BT_BILLING_MAX_CREDIT_GRANT' => '5000' })).to eq(5000)
        expect(described_class.max_credit_grant_minor('USD', { 'BT_BILLING_MAX_CREDIT_GRANT' => 'lots' })).to eq(100_000)
      end

      it 'raises when a feature requires a country that is not configured' do
        expect { described_class.require_default_country!({}) }
          .to raise_error(Configuration::MissingConfigurationError, /BT_BILLING_DEFAULT_COUNTRY/)
      end

      describe '.requested?' do
        it 'is true only when BT_BILLING_ENABLED is switched on' do
          expect(described_class.requested?('BT_BILLING_ENABLED' => 'true')).to be true
          expect(described_class.requested?('BT_BILLING_ENABLED' => 'false')).to be false
          expect(described_class.requested?({})).to be false
        end
      end

      describe '.log_missing!' do
        let(:logger) { instance_double(Logger, warn: nil) }

        it 'warns once, listing the missing keys, for a host that switched billing on' do
          env = full_env.except('PAY_BUSINESS_NAME').merge('BT_BILLING_ENABLED' => 'true')

          described_class.log_missing!(logger, env)

          expect(logger).to have_received(:warn).with(/PAY_BUSINESS_NAME/)
        end

        it 'stays silent for a host that never asked for billing' do
          described_class.log_missing!(logger, {})

          expect(logger).not_to have_received(:warn)
        end

        it 'stays silent when billing is on and fully configured' do
          described_class.log_missing!(logger, full_env.merge('BT_BILLING_ENABLED' => 'true'))

          expect(logger).not_to have_received(:warn)
        end
      end

      describe 'processor contexts' do
        let(:host_platform) { configure_host_platform }
        let(:other_platform) { create(:better_together_platform) }

        before { Billing.register_processor(:fake, -> { FakeAdapter.new }) }

        it 'gives the host platform an environment-backed context' do
          context = described_class.context_for(host_platform, :fake)

          expect(context).to have_attributes(platform: host_platform, processor: :fake, source: :environment)
          expect(context).to be_environment
        end

        it 'gives no other platform a context, so it can never use the host account' do
          expect(described_class.context_for(other_platform, :fake)).to be_nil
          expect(described_class.processors_for(other_platform)).to be_empty
        end

        it 'gives no context for a processor that is not registered, or without a platform' do
          expect(described_class.context_for(host_platform, :ghost)).to be_nil
          expect(described_class.context_for(nil, :fake)).to be_nil
        end

        it 'lists the registered processors a platform has a context for' do
          expect(described_class.processors_for(host_platform)).to eq([:fake])
        end
      end

      describe 'processor contexts for methods outside a vendor' do
        include_context 'with builtin billing processors'

        let(:host_platform) { configure_host_platform }
        let(:other_platform) { create(:better_together_platform) }
        let(:community) { create(:better_together_community) }

        it 'has none until a steward turns the method on' do
          expect(described_class.context_for(host_platform, :cash)).to be_nil
          expect(described_class.processors_for(host_platform)).to be_empty
        end

        it 'has one for the host platform that turned it on, with no credentials' do
          enable_method(host_platform)

          context = described_class.context_for(host_platform, :cash)

          expect(context).to have_attributes(platform: host_platform, processor: :cash, source: :setting, credentials: nil)
          expect(described_class.processors_for(host_platform)).to eq([:cash])
        end

        it 'has one for a hosted platform that holds the hosted agreements and turned it on, with no credentials' do
          grant_hosted_billing(other_platform)
          enable_method(other_platform)

          context = described_class.context_for(other_platform, :cash)

          expect(context).to have_attributes(platform: other_platform, processor: :cash, source: :setting, credentials: nil)
          expect(described_class.processors_for(other_platform)).to eq([:cash])
        end

        it 'has none for a hosted platform that has not accepted the agreements, even with the method turned on' do
          # Written past validation: a row that predates the gate must still have no context.
          other_platform.billing_processor_settings.new(processor: 'cash', enabled: true, acknowledge: true,
                                                        settings: { 'instructions' => 'At the hall' }).save!(validate: false)

          expect(described_class.context_for(other_platform, :cash)).to be_nil
          expect(described_class.processors_for(other_platform)).to be_empty
        end

        it 'does not give the host platform a method another platform turned on' do
          grant_hosted_billing(other_platform)
          enable_method(other_platform)

          expect(described_class.context_for(host_platform, :cash)).to be_nil
        end

        it 'goes again when the method is turned off' do
          setting = enable_method(host_platform)
          setting.update!(enabled: false)

          expect(described_class.context_for(host_platform, :cash)).to be_nil
        end

        it 'keeps the platform and each seller apart' do
          BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'
          enable_method(host_platform, 'cheque', settings: { 'payee_name' => 'A', 'address' => 'B' }, seller: community)

          expect(described_class.context_for(host_platform, :cheque)).to be_nil
          expect(described_class.context_for(host_platform, :cheque, seller: community)).to be_present
          expect(described_class.context_for(host_platform, :cash, seller: community)).to be_nil
        end

        it 'does not depend on the host environment, but a vendor processor still does' do
          Billing.register_processor(:fake, -> { FakeAdapter.new })
          grant_hosted_billing(other_platform)
          enable_method(other_platform)

          expect(described_class.context_for(other_platform, :fake)).to be_nil
          expect(described_class.context_for(host_platform, :cash)).to be_nil
        end
      end

      describe '.platform_for_webhook' do
        let(:host_platform) { configure_host_platform }
        let(:other_platform) { create(:better_together_platform) }

        before { Billing.register_processor(:fake, -> { FakeAdapter.new }) }

        it 'attributes an event with no hint to the only platform that has billing configured' do
          expect(described_class.platform_for_webhook(:fake)).to eq(host_platform)
        end

        it 'honours an event that names its platform, if that platform has billing configured' do
          expect(described_class.platform_for_webhook(:fake, platform_id: host_platform.id)).to eq(host_platform)
          expect(described_class.platform_for_webhook(:fake, platform_id: other_platform.id)).to be_nil
        end

        it 'does not guess when no platform has billing configured for the processor' do
          expect(described_class.platform_for_webhook(:ghost)).to be_nil
        end

        it 'does not guess when more than one platform could own the event' do
          allow(described_class).to receive(:platforms_with_context).and_return([host_platform, other_platform])

          expect(described_class.platform_for_webhook(:fake)).to be_nil
        end

        it 'matches a processor account to the platform whose context names it' do
          allow(described_class).to receive(:platforms_with_context).and_return([host_platform, other_platform])
          allow(described_class).to receive(:context_for) do |platform, processor|
            ProcessorContext.new(platform:, processor:, account_ref: platform == other_platform ? 'acct_b' : 'acct_a')
          end

          expect(described_class.platform_for_webhook(:fake, account_ref: 'acct_b')).to eq(other_platform)
          expect(described_class.platform_for_webhook(:fake, account_ref: 'acct_other')).to be_nil
        end

        it 'refuses an event from a processor account that no context names, rather than giving it to the host' do
          expect(described_class.platform_for_webhook(:fake)).to eq(host_platform)
          expect(described_class.platform_for_webhook(:fake, account_ref: 'acct_connected')).to be_nil
        end
      end
    end
  end
end
