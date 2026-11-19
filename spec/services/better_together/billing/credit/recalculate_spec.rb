# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Credit::Recalculate do
  include_context 'with store credit fixtures'

  before { grant_credit(1000) }

  it 'agrees when the balance, the lots and the entries all say the same' do
    result = described_class.call(account_of)

    expect(result).to have_attributes(balance_cents: 1000, lots_cents: 1000, entries_cents: 1000)
    expect(result).to be_consistent
  end

  it 'reports a balance that has drifted, and sets it back to what the lots say only when asked' do
    account_of.update_columns(balance_cents: 1200) # rubocop:disable Rails/SkipsModelValidations

    expect(described_class.call(account_of)).not_to be_consistent
    expect(account_of.reload.balance_cents).to eq(1200)

    described_class.call(account_of, repair: true)

    expect(account_of.reload.balance_cents).to eq(1000)
  end
end
