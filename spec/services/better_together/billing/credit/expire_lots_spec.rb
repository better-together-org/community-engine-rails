# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Credit::ExpireLots do
  include_context 'with store credit fixtures'

  it 'empties a lot past its date, with an entry for what was lost' do
    lot = grant_credit(1000, expires_at: 1.hour.from_now)
    grant_credit(500)

    expect(described_class.call(now: 2.hours.from_now)).to eq(1)

    expect(lot.reload.remaining_cents).to eq(0)
    expect(account_of.reload.balance_cents).to eq(500)
    expect(account_of.entries.find_by(kind: 'expire')).to have_attributes(amount_cents: -1000, balance_after_cents: 500, lot:)
    expect(account_of).to be_consistent
  end

  it 'only loses what was left after spending' do
    lot = grant_credit(1000, expires_at: 1.hour.from_now)
    order = place_order
    payment = create(:better_together_billing_payment, order:, amount_cents: 400, processor: 'store_credit')
    BetterTogether::Billing::Credit::Spend.call(account: account_of, amount_cents: 400, purpose: 'one_time', source: payment,
                                                idempotency_key: 'spend')

    described_class.call(now: 2.hours.from_now)

    expect(account_of.entries.find_by(kind: 'expire').amount_cents).to eq(-600)
    expect(lot.reload.remaining_cents).to eq(0)
  end

  it 'leaves credit that has not expired, and lets itself be repeated' do
    grant_credit(1000, expires_at: 1.day.from_now)
    grant_credit(1000, expires_at: 1.hour.from_now)

    expect(described_class.call(now: 2.hours.from_now)).to eq(1)
    expect(described_class.call(now: 2.hours.from_now)).to eq(0)
    expect(account_of.reload.balance_cents).to eq(1000)
  end

  it 'can be limited to one platform' do
    grant_credit(1000, expires_at: 1.hour.from_now)

    expect(described_class.call(now: 2.hours.from_now, platform: create(:better_together_platform))).to eq(0)
    expect(described_class.call(now: 2.hours.from_now, platform: host_platform)).to eq(1)
  end
end
