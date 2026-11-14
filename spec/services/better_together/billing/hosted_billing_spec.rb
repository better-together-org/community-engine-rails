# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::HostedBilling do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:host) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:hosted) { create(:better_together_platform) }
  let(:person) { create(:better_together_person) }
  let!(:agreements) { BetterTogether::Billing::HostedAgreementSeeds.call(host) }

  def activate!(*modes)
    modes.each { |mode| agreements.fetch(described_class::AGREEMENT_FOR.fetch(mode)).update!(lifecycle_state: 'active') }
  end

  def accept!(*modes) = modes.each { |mode| described_class.accept!(platform: hosted, mode:, person:) }

  describe 'the seeded agreements' do
    it 'plants three host-owned drafts, once' do
      expect(agreements.keys).to match_array(described_class::AGREEMENT_FOR.values)
      expect(agreements.values).to all(have_attributes(lifecycle_state: 'draft', platform: host))
      expect { BetterTogether::Billing::HostedAgreementSeeds.call(host) }.not_to change(BetterTogether::Agreement, :count)
    end
  end

  describe '.permits?' do
    it 'never gates the host' do
      expect(described_class.permits?(host, :merchant)).to be true
    end

    it 'refuses a hosted platform that has accepted nothing' do
      expect(described_class.permits?(hosted, :billing)).to be false
    end

    it 'refuses while the agreement is still a draft, even if it was accepted' do
      expect { accept!(:billing) }.to raise_error(ArgumentError)
    end

    it 'allows billing after the base agreement, but not local methods' do
      activate!(:billing, :local)
      accept!(:billing)

      expect([described_class.permits?(hosted, :billing), described_class.permits?(hosted, :local)]).to eq([true, false])
    end

    it 'allows local methods only after both agreements' do
      activate!(:billing, :local)
      accept!(:billing, :local)

      expect(described_class.permits?(hosted, :local)).to be true
    end

    it 'does not let the merchant agreement stand in for the base one' do
      activate!(:billing, :merchant)
      accept!(:merchant)

      expect(described_class.permits?(hosted, :merchant)).to be false
    end

    it 'pauses a mode when the host withdraws its agreement, keeping the acceptance' do
      activate!(:billing)
      accept!(:billing)
      agreements.fetch('hosted_platform_billing_agreement').update!(lifecycle_state: 'draft')

      expect(described_class.permits?(hosted, :billing)).to be false
    end

    it 'refuses once the agreement changes and requires acceptance again' do
      activate!(:billing)
      accept!(:billing)
      agreement = agreements.fetch('hosted_platform_billing_agreement')
      agreement.agreement_terms.first.update!(content_en: 'Revised wording for the host billing terms.')

      expect(described_class.permits?(hosted, :billing)).to be false
    end
  end

  describe 'suspension' do
    before do
      activate!(:billing)
      accept!(:billing)
    end

    it 'turns every mode off and records an event, then restores on resume' do
      described_class.suspend!(platform: hosted, by: person, reason: 'Unpaid hosting')

      expect(described_class.permits?(hosted, :billing)).to be false
      expect(hosted.billing_events.where(event_type: 'hosted_billing.suspended').count).to eq(1)

      described_class.resume!(platform: hosted, by: person)

      expect(described_class.permits?(hosted, :billing)).to be true
    end

    it 'does not store the reason in the event payload' do
      described_class.suspend!(platform: hosted, by: person, reason: 'Private note')

      expect(hosted.billing_events.last.payload.to_s).not_to include('Private note')
    end
  end

  describe 'the billing gates' do
    before { activate!(:billing, :local) }

    it 'keeps Billing.enabled? off for a hosted platform until it has agreed and enabled a method' do
      expect(BetterTogether::Billing.enabled?(hosted)).to be false
      expect(BetterTogether::Billing.configurable?(hosted)).to be false
    end

    it 'refuses to enable a local method before both agreements' do
      setting = hosted.billing_processor_settings.new(processor: 'cash', enabled: true, acknowledge: true,
                                                      settings: { 'instructions' => 'Hall' })

      expect(setting).not_to be_valid
      expect(setting.errors[:base]).to be_present
    end

    it 'lets a platform that accepted both agreements use a local method' do
      accept!(:billing, :local)
      hosted.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true, settings: { 'instructions' => 'Hall' })

      expect(BetterTogether::Billing.processor_names).to include(:cash)
      expect(BetterTogether::Billing::Configuration.processors_for(hosted)).to include(:cash)
    end
  end
end
