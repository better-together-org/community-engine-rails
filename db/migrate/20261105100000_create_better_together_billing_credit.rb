# frozen_string_literal: true

# Store credit: a balance a person holds with a platform, spent on what that platform sells.
# Final state; guarded so a re-run, or an interrupted earlier run, is a no-op for what exists.
#
# * credit_accounts: one per platform, holder and currency. `balance_cents` is a cache of the sum of
#   the account's lots and can never go below zero (CHECK). The holder is nullified when the person
#   is deleted; the ledger stays.
# * credit_lots: each amount that came in (a steward's grant, a promotion, a refund), with when it
#   expires and what it may be spent on. `remaining_cents` stays between 0 and the amount (CHECK).
#   Spending takes the lot that expires soonest.
# * credit_entries: the append-only history. One entry per lot touched, signed (grants add, spends
#   subtract), with the balance after it. `transaction_key` groups the entries of one operation and,
#   with the lot, makes repeating the operation harmless.
#
# platform_id is NOT NULL everywhere and the account, lot and reversal links are COMPOSITE foreign keys
# with the platform, so a row can never point at another platform's.
class CreateBetterTogetherBillingCredit < ActiveRecord::Migration[7.2]
  def up
    create_credit_accounts
    create_credit_lots
    create_credit_entries
  end

  def down
    %i[billing_credit_entries billing_credit_lots billing_credit_accounts].each do |name|
      table = :"better_together_#{name}"
      drop_table table, force: :cascade if table_exists?(table)
    end
  end

  private

  def create_credit_accounts
    return if table_exists?(:better_together_billing_credit_accounts)

    create_bt_table :billing_credit_accounts do |t|
      t.uuid :platform_id, null: false
      t.references :holder, type: :uuid, index: false, foreign_key: { to_table: :better_together_people, on_delete: :nullify }
      t.string :currency, null: false
      t.bigint :balance_cents, null: false, default: 0
    end
    table = :better_together_billing_credit_accounts
    add_index table, :platform_id, name: 'idx_bt_billing_credit_accounts_platform'
    add_index table, :holder_id, name: 'idx_bt_billing_credit_accounts_holder'
    add_index table, %i[platform_id holder_id currency], unique: true, name: 'idx_bt_billing_credit_accounts_holder_currency'
    add_index table, %i[id platform_id], unique: true, name: 'idx_bt_billing_credit_accounts_id_platform'
    add_foreign_key table, :better_together_platforms, column: :platform_id
    add_check_constraint table, 'balance_cents >= 0', name: 'chk_bt_billing_credit_accounts_balance'
  end

  def create_credit_lots
    return if table_exists?(:better_together_billing_credit_lots)

    create_bt_table :billing_credit_lots do |t|
      t.uuid :platform_id, null: false
      t.uuid :credit_account_id, null: false
      t.references :granted_by, type: :uuid, index: false, foreign_key: { to_table: :better_together_people, on_delete: :nullify }
      t.string :origin, null: false
      t.bigint :amount_cents, null: false
      t.bigint :remaining_cents, null: false
      t.string :purposes, array: true, null: false, default: []
      t.boolean :promotional, null: false, default: false
      t.string :note
      t.datetime :expires_at
    end
    add_credit_lot_indexes
  end

  def add_credit_lot_indexes
    table = :better_together_billing_credit_lots
    add_index table, :platform_id, name: 'idx_bt_billing_credit_lots_platform'
    add_index table, :granted_by_id, name: 'idx_bt_billing_credit_lots_granted_by'
    add_index table, %i[credit_account_id expires_at], name: 'idx_bt_billing_credit_lots_account_expiry'
    add_index table, :expires_at, where: 'remaining_cents > 0', name: 'idx_bt_billing_credit_lots_expiring'
    add_index table, %i[id platform_id], unique: true, name: 'idx_bt_billing_credit_lots_id_platform'
    add_foreign_key table, :better_together_platforms, column: :platform_id
    add_foreign_key table, :better_together_billing_credit_accounts, column: %i[credit_account_id platform_id], primary_key: %i[id platform_id],
                                                                     name: 'fk_bt_billing_credit_lots_account_platform'
    add_check_constraint table, 'amount_cents > 0 AND remaining_cents >= 0 AND remaining_cents <= amount_cents',
                         name: 'chk_bt_billing_credit_lots_bounds'
  end

  def create_credit_entries
    return if table_exists?(:better_together_billing_credit_entries)

    create_bt_table :billing_credit_entries do |t|
      t.uuid :platform_id, null: false
      t.uuid :credit_account_id, null: false
      t.uuid :credit_lot_id, null: false
      t.uuid :reverses_entry_id
      t.references :actor, type: :uuid, index: false, foreign_key: { to_table: :better_together_people, on_delete: :nullify }
      t.string :kind, null: false
      t.string :transaction_key, null: false
      t.bigint :amount_cents, null: false
      t.bigint :balance_after_cents, null: false
      t.string :source_type
      t.uuid :source_id
      t.string :note
    end
    add_credit_entry_indexes
  end

  def add_credit_entry_indexes
    table = :better_together_billing_credit_entries
    add_index table, :platform_id, name: 'idx_bt_billing_credit_entries_platform'
    add_index table, :actor_id, name: 'idx_bt_billing_credit_entries_actor'
    add_index table, %i[credit_account_id created_at], name: 'idx_bt_billing_credit_entries_account_time'
    add_index table, :credit_lot_id, name: 'idx_bt_billing_credit_entries_lot'
    add_index table, :reverses_entry_id, where: 'reverses_entry_id IS NOT NULL', name: 'idx_bt_billing_credit_entries_reverses'
    add_index table, %i[source_type source_id], name: 'idx_bt_billing_credit_entries_source'
    add_index table, %i[platform_id transaction_key credit_lot_id], unique: true, name: 'idx_bt_billing_credit_entries_transaction'
    add_index table, %i[id platform_id], unique: true, name: 'idx_bt_billing_credit_entries_id_platform'
    add_credit_entry_keys(table)
  end

  def add_credit_entry_keys(table)
    add_foreign_key table, :better_together_platforms, column: :platform_id
    add_foreign_key table, :better_together_billing_credit_accounts, column: %i[credit_account_id platform_id], primary_key: %i[id platform_id],
                                                                     name: 'fk_bt_billing_credit_entries_account_platform'
    add_foreign_key table, :better_together_billing_credit_lots, column: %i[credit_lot_id platform_id], primary_key: %i[id platform_id],
                                                                 name: 'fk_bt_billing_credit_entries_lot_platform'
    add_foreign_key table, table, column: %i[reverses_entry_id platform_id], primary_key: %i[id platform_id],
                                  name: 'fk_bt_billing_credit_entries_reverses_platform'
    add_check_constraint table, 'amount_cents <> 0', name: 'chk_bt_billing_credit_entries_amount'
  end
end
