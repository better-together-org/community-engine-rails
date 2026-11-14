# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ExpireCreditLotsJob do
  include_context 'with store credit fixtures'

  it 'runs on the billing queue' do
    expect(described_class.new.queue_name).to include('billing')
  end

  it 'lets credit past its date go' do
    lot = grant_credit(1000, expires_at: 1.minute.from_now)

    travel_to(2.minutes.from_now) { described_class.perform_now }

    expect(lot.reload.remaining_cents).to eq(0)
    expect(account_of.reload.balance_cents).to eq(0)
  end
end
