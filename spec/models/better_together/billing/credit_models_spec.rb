# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Store credit models' do # rubocop:disable RSpec/DescribeClass
  include_context 'with store credit fixtures'

  let!(:lot) { grant_credit(1000) }
  let(:account) { account_of }
  let(:entry) { account.entries.sole }

  describe BetterTogether::Billing::CreditAccount do
    it 'belongs to a platform and a holder, one per currency' do
      expect(account).to have_attributes(platform: host_platform, holder: buyer, currency: 'USD')
      duplicate = host_platform.billing_credit_accounts.build(holder: buyer, currency: 'USD')

      expect(duplicate).not_to be_valid
    end

    it 'keeps the platform and the holder it began with' do
      expect(account.update(platform: create(:better_together_platform))).to be(false)
      expect { account.update!(holder: steward) }.not_to(change { account.reload.holder_id })
    end

    it 'cannot go below zero, in the model or the database' do
      account.balance_cents = -1
      expect(account).not_to be_valid
      expect { account.update_columns(balance_cents: -1) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::StatementInvalid, /chk_bt_billing_credit_accounts_balance/)
    end

    it 'counts what can be spent now for a kind of purchase' do
      grant_credit(300, purposes: %w[ticket])
      grant_credit(200, expires_at: 1.day.ago)

      expect(account.usable_cents).to eq(1300)
      expect(account.usable_cents(purpose: 'one_time')).to eq(1000)
    end

    it 'keeps the ledger when the person is deleted, with no holder left' do
      kept = account
      BetterTogether::Person.where(id: buyer.id).delete_all

      expect(kept.reload.holder_id).to be_nil
      expect(kept.entries.count).to eq(1)
    end

    it 'refuses to be deleted with a history' do
      expect(account.destroy).to be(false)
    end

    it 'is reached through its platform' do
      expect(host_platform.billing_credit_accounts).to include(account)
    end
  end

  describe BetterTogether::Billing::CreditLot do
    it 'stays between nothing and what it began with, in the model and the database' do
      lot.remaining_cents = 1001
      expect(lot).not_to be_valid
      expect { lot.update_columns(remaining_cents: 1001) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::StatementInvalid, /chk_bt_billing_credit_lots_bounds/)
    end

    it 'keeps its amount and origin' do
      lot.update!(amount_cents: 5000, origin: 'promotion', remaining_cents: 1000)

      expect(lot.reload).to have_attributes(amount_cents: 1000, origin: 'steward_grant')
    end

    it 'only allows purposes that are kinds of purchase' do
      lot.purposes = %w[one_time nonsense]
      expect(lot).not_to be_valid
    end

    it 'knows when it has expired' do
      expect(lot).not_to be_expired
      lot.expires_at = 1.minute.ago
      expect(lot).to be_expired
    end

    it 'must agree with its account on the platform' do
      lot.platform_id = create(:better_together_platform).id
      expect(lot).not_to be_valid
    end
  end

  describe BetterTogether::Billing::CreditEntry do
    it 'is append-only: it cannot be changed or removed once written' do
      expect(entry).to be_readonly
      expect { entry.update!(note: 'changed') }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { entry.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'has a sign that fits what it is' do
      wrong = account.entries.build(platform_id: host_platform.id, lot:, kind: 'spend', amount_cents: 5, balance_after_cents: 0,
                                    transaction_key: 'x')

      expect(wrong).not_to be_valid
    end

    it 'is never for nothing, in the model and the database' do
      zero = account.entries.build(platform_id: host_platform.id, lot:, kind: 'grant', amount_cents: 0, balance_after_cents: 0,
                                   transaction_key: 'zero')
      expect(zero).not_to be_valid
    end

    it 'only names a payment or a refund as its source' do
      other = account.entries.build(platform_id: host_platform.id, lot:, kind: 'grant', amount_cents: 5, balance_after_cents: 5,
                                    transaction_key: 'y', source_type: 'BetterTogether::Person', source_id: buyer.id)

      expect(other).not_to be_valid
    end

    it 'cannot repeat a transaction on the same lot' do
      again = account.entries.build(platform_id: host_platform.id, lot:, kind: 'grant', amount_cents: 5, balance_after_cents: 5,
                                    transaction_key: entry.transaction_key)

      expect(again).not_to be_valid
    end

    it 'refuses a lot from another account' do
      other_lot = grant_credit(100, holder: create(:better_together_person))
      mismatch = account.entries.build(platform_id: host_platform.id, lot: other_lot, kind: 'grant', amount_cents: 5, balance_after_cents: 5,
                                       transaction_key: 'z')

      expect(mismatch).not_to be_valid
    end
  end
end
