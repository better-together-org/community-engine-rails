# frozen_string_literal: true

# Processor-neutral orders, their lines, the payments made against them and the refunds of
# those payments. Final state; guarded so a re-run is a no-op.
#
# * Every table carries platform_id NOT NULL, and a child is tied to its parent's platform by a
#   COMPOSITE foreign key (parent_id, platform_id), so a line, payment or refund can never
#   belong to a different platform than its order.
# * seller empty means the platform itself sells; otherwise a community or person on it. The
#   buyer is always a person; on_behalf_of is the community or person the purchase is for.
# * number is the human reference, unique per platform.
# * A payment is one payment made against an order through one method (a vendor processor,
#   cash, store credit...), so an order can be paid in parts by different methods. Its
#   idempotency key makes repeating a request harmless. A refund belongs to one payment.
# * Money is integer minor units plus an ISO currency, never a float.
class CreateBetterTogetherBillingOrders < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  def up
    create_orders
    create_order_lines
    create_payments
    create_refunds
  end

  def down
    %i[better_together_billing_refunds better_together_billing_payments better_together_billing_order_lines
       better_together_billing_orders].each { |table| drop_table table if table_exists?(table) }
  end

  private

  def create_orders # rubocop:disable Metrics/MethodLength
    return if table_exists?(:better_together_billing_orders)

    create_bt_table :billing_orders do |t|
      t.references :platform, null: false, type: :uuid, index: { name: 'idx_bt_billing_orders_platform' },
                              foreign_key: { to_table: :better_together_platforms }
      t.string :seller_type
      t.uuid :seller_id
      t.references :buyer, null: false, type: :uuid, index: { name: 'idx_bt_billing_orders_buyer' },
                           foreign_key: { to_table: :better_together_people }
      t.string :on_behalf_of_type
      t.uuid :on_behalf_of_id
      t.string :subject_type
      t.uuid :subject_id
      t.string :number, null: false
      t.string :purpose, null: false
      t.string :status, null: false, default: 'draft'
      t.string :currency, null: false
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.datetime :placed_at
      t.datetime :expires_at
      t.datetime :paid_at
      t.datetime :cancelled_at
    end

    add_index :better_together_billing_orders, %i[id platform_id], unique: true, name: 'idx_bt_billing_orders_id_platform'
    add_index :better_together_billing_orders, %i[platform_id number], unique: true, name: 'idx_bt_billing_orders_number'
    add_index :better_together_billing_orders, %i[seller_type seller_id], name: 'idx_bt_billing_orders_seller'
    add_index :better_together_billing_orders, %i[on_behalf_of_type on_behalf_of_id], name: 'idx_bt_billing_orders_on_behalf_of'
    add_index :better_together_billing_orders, %i[subject_type subject_id], name: 'idx_bt_billing_orders_subject'
    add_index :better_together_billing_orders, %i[status expires_at], name: 'idx_bt_billing_orders_status_expires'
  end

  def create_order_lines
    return if table_exists?(:better_together_billing_order_lines)

    create_bt_table :billing_order_lines do |t|
      t.uuid :platform_id, null: false
      t.uuid :order_id, null: false
      t.string :purchasable_type, null: false
      t.uuid :purchasable_id, null: false
      t.string :description, null: false
      t.integer :quantity, null: false, default: 1
      t.integer :unit_amount_cents, null: false
      t.string :currency, null: false
      t.integer :position, null: false, default: 0
    end

    add_index :better_together_billing_order_lines, :platform_id, name: 'idx_bt_billing_order_lines_platform'
    add_index :better_together_billing_order_lines, :order_id, name: 'idx_bt_billing_order_lines_order'
    add_index :better_together_billing_order_lines, %i[purchasable_type purchasable_id], name: 'idx_bt_billing_order_lines_purchasable'
    add_foreign_key :better_together_billing_order_lines, :better_together_platforms, column: :platform_id
    add_foreign_key :better_together_billing_order_lines, :better_together_billing_orders,
                    column: %i[order_id platform_id], primary_key: %i[id platform_id], name: 'fk_bt_billing_order_lines_order_platform'
  end

  def create_payments # rubocop:disable Metrics/MethodLength
    return if table_exists?(:better_together_billing_payments)

    create_bt_table :billing_payments do |t|
      t.uuid :platform_id, null: false
      t.uuid :order_id, null: false
      t.string :processor, null: false
      t.string :status, null: false, default: 'pending'
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.string :idempotency_key, null: false
      t.string :processor_reference
      t.datetime :paid_at
      t.datetime :failed_at
    end

    add_index :better_together_billing_payments, :platform_id, name: 'idx_bt_billing_payments_platform'
    add_index :better_together_billing_payments, :order_id, name: 'idx_bt_billing_payments_order'
    add_index :better_together_billing_payments, %i[id platform_id], unique: true, name: 'idx_bt_billing_payments_id_platform'
    add_index :better_together_billing_payments, %i[platform_id idempotency_key], unique: true, name: 'idx_bt_billing_payments_idempotency'
    add_index :better_together_billing_payments, %i[processor processor_reference], name: 'idx_bt_billing_payments_reference'
    add_index :better_together_billing_payments, :status, name: 'idx_bt_billing_payments_status'
    add_foreign_key :better_together_billing_payments, :better_together_platforms, column: :platform_id
    add_foreign_key :better_together_billing_payments, :better_together_billing_orders,
                    column: %i[order_id platform_id], primary_key: %i[id platform_id], name: 'fk_bt_billing_payments_order_platform'
  end

  def create_refunds # rubocop:disable Metrics/MethodLength
    return if table_exists?(:better_together_billing_refunds)

    create_bt_table :billing_refunds do |t|
      t.uuid :platform_id, null: false
      t.uuid :payment_id, null: false
      t.references :recorded_by, type: :uuid, index: { name: 'idx_bt_billing_refunds_recorded_by' },
                                 foreign_key: { to_table: :better_together_people, on_delete: :nullify }
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.string :status, null: false, default: 'pending'
      t.string :reason
      t.string :idempotency_key, null: false
      t.string :processor_reference
    end

    add_index :better_together_billing_refunds, :platform_id, name: 'idx_bt_billing_refunds_platform'
    add_index :better_together_billing_refunds, :payment_id, name: 'idx_bt_billing_refunds_payment'
    add_index :better_together_billing_refunds, %i[platform_id idempotency_key], unique: true, name: 'idx_bt_billing_refunds_idempotency'
    add_foreign_key :better_together_billing_refunds, :better_together_platforms, column: :platform_id
    add_foreign_key :better_together_billing_refunds, :better_together_billing_payments,
                    column: %i[payment_id platform_id], primary_key: %i[id platform_id], name: 'fk_bt_billing_refunds_payment_platform'
  end
end
