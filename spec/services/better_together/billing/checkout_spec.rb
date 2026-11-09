# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Checkout services' do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'

  def agreements = BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform)
  def activate_all = agreements.each_value { |agreement| agreement.update!(lifecycle_state: 'active') }

  def choices(of_plan) = BetterTogether::Billing::Checkout::Methods.call(platform: host_platform, plan: of_plan).index_by(&:name)

  let(:details) do
    { 'cash' => { 'instructions' => 'Hall' }, 'etransfer' => { 'recipient_email' => 'a@example.test' },
      'cheque' => { 'payee_name' => 'A', 'address' => 'B' } }
  end

  def enable(method, **attrs)
    host_platform.billing_processor_settings.create!({ processor: method, enabled: true, acknowledge: true,
                                                       settings: details.fetch(method) }.merge(attrs))
  end

  def with_billing_on
    previous = ENV.fetch('BT_BILLING_ENABLED', nil)
    ENV['BT_BILLING_ENABLED'] = 'true'
    yield
  ensure
    previous.nil? ? ENV.delete('BT_BILLING_ENABLED') : ENV['BT_BILLING_ENABLED'] = previous
  end

  def gate(**attrs)
    BetterTogether::Billing::Checkout::AgreementGate.new(platform: host_platform, purpose: 'one_time', signer: buyer,
                                                         purchasables: [plan], **attrs)
  end

  describe BetterTogether::Billing::Checkout::AgreementGate do
    it 'is not ready, and offers nothing to accept, while the purchase agreements are only drafts' do
      agreements

      expect(gate).not_to be_ready
      expect(gate.problems.map(&:code)).to eq([:not_in_force])
      expect(gate).not_to be_satisfied
      expect { gate.accept! }.to raise_error(described_class::NotReady)
    end

    it 'is not ready when the platform requires no purchase agreement at all' do
      host_platform.billing_agreement_requirements.destroy_all

      expect(gate.problems.map(&:code)).to eq([:no_agreement])
    end

    it 'is not ready when an agreement is retired or switched off for consent' do
      activate_all
      agreements['one_time_purchase_agreement'].update!(lifecycle_state: 'retired')
      expect(gate).not_to be_ready

      agreements['one_time_purchase_agreement'].update!(lifecycle_state: 'active', active_for_consent: false)
      expect(gate).not_to be_ready
    end

    it 'is ready, with something to accept, once the agreements are in force' do
      activate_all

      expect(gate).to be_ready
      expect(gate.missing.map(&:identifier)).to eq(['one_time_purchase_agreement'])
      expect(gate).not_to be_satisfied
    end

    it 'records the signer\'s acceptance, and is then satisfied' do
      activate_all

      gate.accept!(method: 'checkout')

      expect(gate).to be_satisfied
      expect(buyer.agreement_participants.last).to have_attributes(acceptance_method: 'checkout')
    end

    it 'needs another acceptance when an agreement that requires it changes' do
      activate_all
      gate.accept!
      agreements['one_time_purchase_agreement'].update!(title: 'Changed terms')

      expect(gate(signer: buyer)).not_to be_satisfied
      expect(gate(signer: buyer).missing.map(&:identifier)).to eq(['one_time_purchase_agreement'])
    end

    it 'does not take one person\'s acceptance for another\'s' do
      activate_all
      gate.accept!

      expect(gate(signer: create(:better_together_person))).not_to be_satisfied
    end

    it 'asks for the terms that come with a payment method too' do
      activate_all

      expect(gate(payment_method: 'cash').missing.map(&:identifier)).to eq(%w[one_time_purchase_agreement offline_payment_terms])
    end

    it 'asks only for the kind of purchase being made' do
      activate_all

      expect(gate(purpose: 'subscription').missing.map(&:identifier)).to eq(['subscription_agreement'])
    end
  end

  describe BetterTogether::Billing::Checkout::Methods do
    let(:cash_plan) { create(:better_together_billing_plan, accepted_payment_methods: %w[cash etransfer], currency: 'USD') }

    it 'lists the online processor and the other methods a plan accepts' do
      expect(choices(cash_plan).keys).to eq(%w[fake cash etransfer])
    end

    it 'offers a method only when it is switched on' do
      enable('cash')

      expect(choices(cash_plan)['cash']).to be_available
      expect(choices(cash_plan)['etransfer']).to have_attributes(available: false, reason: :not_enabled)
    end

    it 'lists a method that is not switched on with the reason, so the buyer is never left wondering' do
      expect(choices(cash_plan)['cash']).to have_attributes(available: false, reason: :not_enabled)
    end

    it 'does not offer a method for a kind of purchase it was not turned on for' do
      enable('cash', purposes: %w[ticket])

      expect(choices(cash_plan)['cash']).to have_attributes(available: false, reason: :purpose_not_allowed)
    end

    it 'does not offer a method that does not work in the plan\'s currency' do
      allow(BetterTogether::Billing::Configuration).to receive(:default_country).and_return('CA')
      enable('etransfer')

      expect(choices(cash_plan)['etransfer']).to have_attributes(available: false, reason: :currency_not_supported)
      expect(choices(create(:better_together_billing_plan, accepted_payment_methods: %w[etransfer],
                                                           currency: 'CAD'))['etransfer']).to be_available
    end

    it 'does not list a method the plan does not accept, even if it is switched on' do
      enable('cheque', settings: { 'payee_name' => 'A', 'address' => 'B' })

      expect(choices(cash_plan).keys).not_to include('cheque')
    end

    it 'calls a plan that renews a subscription, and any other a one-time purchase' do
      monthly = create(:better_together_billing_plan, billing_interval: 'month')
      once = create(:better_together_billing_plan, billing_interval: 'one_time')

      expect(described_class.new(platform: host_platform, plan: monthly).purpose).to eq('subscription')
      expect(described_class.new(platform: host_platform, plan: once).purpose).to eq('one_time')
    end
  end

  describe BetterTogether::Billing::Readiness do
    it 'says what is still to do, in plain keys' do
      result = described_class.call(host_platform)

      expect(result).not_to be_ready
      expect(result.pending.map(&:key)).to include(:configured, :agreements)
    end

    it 'asks for a payment method to be turned on' do
      BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
      BetterTogether::Billing.register_builtin_processors!

      expect(described_class.call(host_platform).pending.map(&:key)).to include(:method_enabled)
    end

    it 'is ready once billing is configured, a method is on and the agreements are in force' do
      activate_all
      host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                       settings: { 'instructions' => 'Hall' })

      with_billing_on { expect(described_class.call(host_platform)).to be_ready }
    end

    it 'names the problem with an agreement that is not in force' do
      agreements
      check = described_class.call(host_platform).checks.find { |item| item.key == :agreements && item.purpose == 'subscription' }

      expect(check).to have_attributes(ok: false, detail: [:not_in_force])
    end
  end
end
