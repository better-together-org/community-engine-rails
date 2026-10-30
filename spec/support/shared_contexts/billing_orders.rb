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

  def place_order(**attrs)
    BetterTogether::Billing::Orders::Place.call(platform: host_platform, buyer:, purpose: 'one_time',
                                                lines: [{ purchasable: plan }], **attrs)
  end
end
