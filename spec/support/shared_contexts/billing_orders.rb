# frozen_string_literal: true

# A host platform with a registered vendor processor ("fake"), a buyer and a plan to buy, for
# specs about orders and payments.
RSpec.shared_context 'with orders fixtures' do
  include_context 'with clean billing processors'

  let!(:host_platform) { configure_host_platform }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[checkout plan_sync]) }
  let(:buyer) { create(:better_together_person) }
  let(:plan) { create(:better_together_billing_plan, amount_cents: 4500, currency: 'USD') }

  before { BetterTogether::Billing.register_processor(:fake, -> { adapter }) }

  # Places an order. The buyer first accepts the purchase agreements, which are set up and in
  # force, as they would at checkout; pass `agreements: false` to leave that undone.
  def place_order(agreements: true, **attrs)
    options = { platform: host_platform, buyer:, purpose: 'one_time', lines: [{ purchasable: plan }] }.merge(attrs)
    accept_purchase_agreements(options) if agreements
    BetterTogether::Billing::Orders::Place.call(**options)
  end

  # The platform's seeded purchase agreements, activated.
  def purchase_agreements_for(platform)
    BetterTogether::Billing::PurchaseAgreementSeeds.call(platform).each_value { |agreement| agreement.update!(lifecycle_state: 'active') }
  end

  def accept_purchase_agreements(options)
    purchase_agreements_for(options.fetch(:platform))
    gate = BetterTogether::Billing::Checkout::AgreementGate.new(
      platform: options.fetch(:platform), purpose: options.fetch(:purpose), signer: options[:signer] || options.fetch(:buyer),
      seller: options[:seller], purchasables: options.fetch(:lines).pluck(:purchasable), payment_method: options[:payment_method]
    )
    gate.accept!
  end
end
