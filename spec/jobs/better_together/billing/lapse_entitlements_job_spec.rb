# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::LapseEntitlementsJob do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  def entitlement_for(order, ends_at, beneficiary: buyer)
    host_platform.billing_entitlements.create!(plan: sub_plan, beneficiary:, order:, starts_at: 2.days.ago, ends_at:)
  end

  it 'syncs each order whose live entitlement has reached its end, and only those' do
    ended = place_order(purpose: 'one_time', payment_method: 'cash', line_items: [{ purchasable: sub_plan }])
    running = place_order(purpose: 'one_time', payment_method: 'cash', line_items: [{ purchasable: sub_plan }])
    entitlement_for(ended, 1.day.ago)
    entitlement_for(running, 1.day.from_now, beneficiary: create(:better_together_person))
    allow(BetterTogether::Billing::Entitlements::Sync).to receive(:order)

    described_class.perform_now

    expect(BetterTogether::Billing::Entitlements::Sync).to have_received(:order).with(ended)
    expect(BetterTogether::Billing::Entitlements::Sync).not_to have_received(:order).with(running)
  end
end
