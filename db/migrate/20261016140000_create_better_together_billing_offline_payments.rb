# frozen_string_literal: true

# The record of an order being paid with money the platform cannot see: cash, a cheque, an
# e-transfer. It sits beside the core payment and carries what only these methods have: the
# buyer's optional "I sent it", who the seller says received it and when, and a snapshot of
# the instructions the buyer was shown. Final state; guarded so a re-run is a no-op.
#
# * platform_id NOT NULL, and COMPOSITE foreign keys (order_id, platform_id) and
#   (payment_id, platform_id), so it can never belong to a different platform than its order.
# * One offline payment per payment (unique payment_id).
# * buyer_reference, seller_reference and instructions_snapshot are encrypted text: a
#   reference can name a person, and the snapshot holds where to send money.
# * platform_fee_cents is always 0: the platform cannot collect a fee on money it never sees.
class CreateBetterTogetherBillingOfflinePayments < ActiveRecord::Migration[7.2]
  def up
    return if table_exists?(:better_together_billing_offline_payments)

    create_offline_payments
    add_offline_payment_indexes
    add_offline_payment_keys
  end

  def down
    drop_table :better_together_billing_offline_payments, force: :cascade if table_exists?(:better_together_billing_offline_payments)
  end

  private

  def create_offline_payments # rubocop:disable Metrics/MethodLength
    create_bt_table :billing_offline_payments do |t| # rubocop:disable Metrics/BlockLength
      t.uuid :platform_id, null: false
      t.uuid :order_id, null: false
      t.uuid :payment_id, null: false
      t.references :confirmed_by, type: :uuid, index: { name: 'idx_bt_billing_offline_payments_confirmed_by' },
                                  foreign_key: { to_table: :better_together_people, on_delete: :nullify }
      t.string :processor, null: false
      t.string :status, null: false, default: 'awaiting'
      t.string :grant_on, null: false, default: 'confirmed'
      t.boolean :seller_assisted, null: false, default: false
      t.integer :platform_fee_cents, null: false, default: 0
      t.integer :claim_count, null: false, default: 0
      t.string :rejection_reason
      t.date :received_on
      t.text :buyer_reference
      t.text :seller_reference
      t.text :instructions_snapshot
      t.datetime :expires_at
      t.datetime :claimed_at
      t.datetime :confirmed_at
      t.datetime :received_at
      t.datetime :cleared_at
      t.datetime :bounced_at
      t.datetime :rejected_at
      t.datetime :expired_at
      t.datetime :cancelled_at
      t.datetime :last_reminded_at
    end
  end

  def add_offline_payment_indexes
    table = :better_together_billing_offline_payments
    add_index table, :platform_id, name: 'idx_bt_billing_offline_payments_platform'
    add_index table, :order_id, name: 'idx_bt_billing_offline_payments_order'
    add_index table, :payment_id, unique: true, name: 'idx_bt_billing_offline_payments_payment'
    add_index table, %i[id platform_id], unique: true, name: 'idx_bt_billing_offline_payments_id_platform'
    add_index table, %i[platform_id status], name: 'idx_bt_billing_offline_payments_status'
    add_index table, %i[status expires_at], name: 'idx_bt_billing_offline_payments_status_expires'
  end

  def add_offline_payment_keys
    table = :better_together_billing_offline_payments
    add_foreign_key table, :better_together_platforms, column: :platform_id
    add_foreign_key table, :better_together_billing_orders, column: %i[order_id platform_id], primary_key: %i[id platform_id],
                                                            name: 'fk_bt_billing_offline_payments_order_platform'
    add_foreign_key table, :better_together_billing_payments, column: %i[payment_id platform_id], primary_key: %i[id platform_id],
                                                              name: 'fk_bt_billing_offline_payments_payment_platform'
  end
end
