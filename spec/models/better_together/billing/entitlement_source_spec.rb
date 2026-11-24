# frozen_string_literal: true

require 'rails_helper'

# A one-time purchase's entitlement belongs to its order, and a subscription's to its subscription, never both.
RSpec.describe BetterTogether::Billing::Entitlement, '#valid? source' do # rubocop:disable RSpec/SpecFilePathFormat
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  it 'is refused with neither a subscription nor an order' do
    entitlement = host_platform.billing_entitlements.build(plan: sub_plan, beneficiary: buyer, starts_at: Time.current)

    expect(entitlement).not_to be_valid
  end

  it 'is refused with both a subscription and an order' do
    term = start_subscription
    order = place_order(purpose: 'one_time', payment_method: 'cash', line_items: [{ purchasable: sub_plan }])
    entitlement = host_platform.billing_entitlements.build(plan: sub_plan, beneficiary: buyer, starts_at: Time.current,
                                                           pay_subscription: term.pay_subscription, order:)

    expect(entitlement).not_to be_valid
  end
end
