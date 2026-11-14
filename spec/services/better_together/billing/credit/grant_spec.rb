# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Credit::Grant do
  include_context 'with store credit fixtures'

  def grant(**attrs)
    described_class.call(platform: host_platform, holder: buyer, amount_cents: 2500, currency: 'USD', origin: 'steward_grant',
                         actor: steward, idempotency_key: 'grant-1', **attrs)
  end

  it 'gives credit as a lot, with an entry for it and a balance that adds up' do
    lot = grant(note: 'Welcome', purposes: %w[one_time])

    expect(lot).to have_attributes(origin: 'steward_grant', amount_cents: 2500, remaining_cents: 2500, granted_by: steward,
                                   purposes: %w[one_time], note: 'Welcome')
    expect(account_of).to have_attributes(balance_cents: 2500, platform_id: host_platform.id)
    expect(account_of.entries.sole).to have_attributes(kind: 'grant', amount_cents: 2500, balance_after_cents: 2500, actor: steward, lot:)
    expect(account_of).to be_consistent
  end

  it 'keeps one account per person and currency, adding to it' do
    grant
    grant(idempotency_key: 'grant-2', amount_cents: 500)
    grant(idempotency_key: 'grant-3', currency: 'CAD')

    expect(host_platform.billing_credit_accounts.where(holder: buyer).pluck(:currency, :balance_cents))
      .to contain_exactly(['USD', 3000], ['CAD', 2500])
  end

  it 'returns the lot it already made when the request is repeated' do
    first = grant

    expect { expect(grant).to eq(first) }.not_to change(BetterTogether::Billing::CreditEntry, :count)
    expect(account_of.balance_cents).to eq(2500)
  end

  it 'never lets a steward give themselves credit' do
    expect { grant(holder: steward) }.to raise_error(BetterTogether::Billing::Credit::Refused, /themselves/)
    expect(host_platform.billing_credit_accounts.where(holder: steward).sum(:balance_cents)).to eq(0)
  end

  it 'refuses a steward grant above the configured maximum, but not a system grant' do
    expect { grant(amount_cents: 100_001) }.to raise_error(BetterTogether::Billing::Credit::Refused, /maximum/)
    expect(grant(origin: 'promotion', actor: nil, amount_cents: 100_001, idempotency_key: 'promo-1')).to be_persisted
  end

  it 'refuses nothing, a negative amount, an unknown origin and a steward grant with no steward' do
    [{ amount_cents: 0 }, { amount_cents: -5 }, { origin: 'gift' }, { actor: nil }, { idempotency_key: '' }].each do |attrs|
      expect { grant(**attrs) }.to raise_error(BetterTogether::Billing::Credit::Refused)
    end
  end

  it 'lets the system grant a promotion or refund with no actor' do
    lot = grant(origin: 'promotion', actor: nil, promotional: true, expires_at: 10.days.from_now)

    expect(lot).to have_attributes(origin: 'promotion', promotional: true, granted_by: nil)
  end

  it 'refuses a purpose that is not a kind of purchase' do
    expect { grant(purposes: %w[bribes]) }.to raise_error(BetterTogether::Billing::Credit::Refused)
  end
end
