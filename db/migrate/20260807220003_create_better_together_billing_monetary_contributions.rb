# frozen_string_literal: true

class CreateBetterTogetherBillingMonetaryContributions < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_billing_monetary_contributions)

    create_bt_table :billing_monetary_contributions do |t|
      t.references :sponsorship,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :better_together_billing_sponsorships }
      t.references :one_time_payment,
                   type: :uuid,
                   null: true,
                   foreign_key: { to_table: :better_together_billing_one_time_payments }
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.string :stripe_balance_transaction_id, null: false
      t.string :stripe_payment_intent_id
      t.jsonb :metadata, null: false, default: {}
    end

    add_index :better_together_billing_monetary_contributions, :stripe_balance_transaction_id,
              unique: true, name: 'idx_bt_billing_monetary_contributions_balance_txn'
  end
end
