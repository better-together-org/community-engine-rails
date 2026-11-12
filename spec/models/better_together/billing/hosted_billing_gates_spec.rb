# frozen_string_literal: true

require 'rails_helper'

# What the hosted billing gate shuts off, and that it leaves the host and the flag-off state alone.
RSpec.describe BetterTogether::Billing::HostedBilling, 'gates' do # rubocop:disable RSpec/DescribeMethod
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'
  include_context 'with subscription fixtures'

  let(:hosted) { create(:better_together_platform) }
  let(:steward_person) { create(:better_together_person) }
  let(:env) { ENV.to_h }

  def enable_cash_for(platform)
    platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                settings: { 'instructions' => 'At the hall' })
  end

  describe 'a hosted platform that has not accepted' do
    it 'cannot sell, configure, or hold a method context' do
      expect(BetterTogether::Billing.enabled?(hosted)).to be(false)
      expect(BetterTogether::Billing.configurable?(hosted)).to be(false)
      expect(BetterTogether::Billing::Configuration.context_for(hosted, :cash)).to be_nil
    end

    it 'cannot switch a method on' do
      setting = hosted.billing_processor_settings.new(processor: 'cash', enabled: true, acknowledge: true,
                                                      settings: { 'instructions' => 'At the hall' })

      expect(setting).not_to be_valid
    end

    it 'can sell once it accepted and turned a method on' do
      grant_hosted_billing(hosted)
      enable_cash_for(hosted)

      expect(BetterTogether::Billing.enabled?(hosted)).to be(true)
    end

    it 'has a vendor processor context for nobody but the host, accepted or not' do
      BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })
      grant_hosted_billing(hosted)

      expect(BetterTogether::Billing::Configuration.context_for(hosted, :fake)).to be_nil
      expect(BetterTogether::Billing::Configuration.context_for(host_platform, :fake)).to be_present
    end
  end

  describe 'suspension' do
    before do
      grant_hosted_billing(hosted)
      enable_cash_for(hosted)
      described_class.suspend!(platform: hosted, by: steward_person, reason: 'Unpaid hosting')
    end

    it 'stops checkout and every billing screen for the platform, and keeps its data' do
      expect(BetterTogether::Billing.enabled?(hosted)).to be(false)
      expect(BetterTogether::Billing::Configuration.processors_for(hosted)).to be_empty
      expect(hosted.billing_processor_settings.enabled.count).to eq(1)
    end

    it 'stops webhook attribution to the platform' do
      expect(BetterTogether::Billing::Configuration.platform_for_webhook(:cash, platform_id: hosted.id)).to be_nil
    end

    it 'comes back on resume' do
      described_class.resume!(platform: hosted, by: steward_person)

      expect(BetterTogether::Billing.enabled?(hosted)).to be(true)
    end
  end

  describe 'recurring subscription jobs' do
    it 'skips a subscription whose platform the gate refuses, and runs it again when the gate allows' do
      term = start_subscription
      allow(described_class).to receive(:permits?).with(term.platform, :billing).and_return(false)

      travel_to(Time.utc(2027, 2, 20)) { BetterTogether::Billing::GenerateRenewalsJob.perform_now }
      expect(term.reload.periods.count).to eq(1)

      travel_to(Time.utc(2027, 3, 1)) { BetterTogether::Billing::AdvanceSubscriptionsJob.perform_now }
      expect(term.reload.pay_subscription.status).to eq('active')

      allow(described_class).to receive(:permits?).with(term.platform, :billing).and_call_original
      travel_to(Time.utc(2027, 2, 20)) { BetterTogether::Billing::GenerateRenewalsJob.perform_now }
      expect(term.reload.periods.count).to eq(2)
    end
  end

  describe 'the host' do
    it 'is never gated, with no hosted agreement seeded or accepted' do
      expect(BetterTogether::Agreement.where(identifier: described_class::AGREEMENT_FOR.values)).to be_empty
      expect(described_class.permits?(host_platform, :billing)).to be(true)
      expect(described_class.permits?(host_platform, :local)).to be(true)
      expect(BetterTogether::Billing.configurable?(host_platform)).to be(true)
      expect(BetterTogether::Billing::Configuration.context_for(host_platform, :cash)).to be_present
    end

    it 'is not suspended by a hosted account row' do
      expect(described_class.suspended?(host_platform)).to be(false)
    end
  end

  describe 'billing switched off' do
    it 'stays inert for a hosted platform that accepted everything' do
      grant_hosted_billing(hosted)
      enable_cash_for(hosted)
      allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)
      Current.billing_enabled = nil

      expect(BetterTogether::Billing.enabled?(hosted)).to be(false)
      expect(BetterTogether::Billing.configurable?(hosted)).to be(false)
    end
  end
end
