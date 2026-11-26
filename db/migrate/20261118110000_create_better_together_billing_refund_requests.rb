# frozen_string_literal: true

# A buyer's request for money back on an order, and what the seller decided. Guarded so a re-run is a no-op.
#
# * amount_cents empty means "all that can be given back"; approved_amount_cents is what the seller agreed to.
# * details and decision_note are `text` because the model encrypts them: they are free text from a person.
# * A request is decided once. Giving the money back is recorded as ordinary refunds against the order's payments.
class CreateBetterTogetherBillingRefundRequests < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_refund_requests

  def up
    return if table_exists?(TABLE)

    create_bt_table :billing_refund_requests do |t|
      t.references :platform, null: false, type: :uuid, index: { name: 'idx_bt_billing_refund_requests_platform' },
                              foreign_key: { to_table: :better_together_platforms }
      t.references :order, null: false, type: :uuid, index: { name: 'idx_bt_billing_refund_requests_order' },
                           foreign_key: { to_table: :better_together_billing_orders }
      t.references :requester, null: false, type: :uuid, index: { name: 'idx_bt_billing_refund_requests_requester' },
                               foreign_key: { to_table: :better_together_people }
      t.integer :amount_cents
      t.integer :approved_amount_cents
      t.string :currency, null: false
      t.string :reason, null: false
      t.string :status, null: false, default: 'pending'
      t.text :details
      t.text :decision_note
      t.datetime :decided_at
      t.references :decided_by, type: :uuid, index: { name: 'idx_bt_billing_refund_requests_decided_by' },
                                foreign_key: { to_table: :better_together_people, on_delete: :nullify }
    end

    add_index TABLE, %i[platform_id status], name: 'idx_bt_billing_refund_requests_status'
    add_index TABLE, :order_id, unique: true, where: "status = 'pending'", name: 'idx_bt_billing_refund_requests_one_pending'
  end

  def down
    drop_table TABLE if table_exists?(TABLE)
  end
end
