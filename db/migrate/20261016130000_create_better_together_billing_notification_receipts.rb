# frozen_string_literal: true

# One row per notification sent to one person for one thing, so the same event never notifies
# twice: a replayed webhook, a retried job and a double click all find the receipt already there.
# Final state; guarded so a re-run is a no-op.
#
# * platform_id NOT NULL: a receipt belongs to the platform the notification is about.
# * (platform_id, recipient_id, kind, dedupe_key) is unique. The key says what the notification is
#   about (an order and what happened to it, a processed event), never any personal data.
# * A receipt goes with the person it was for.
class CreateBetterTogetherBillingNotificationReceipts < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_notification_receipts

  def up
    return if table_exists?(TABLE)

    create_bt_table :billing_notification_receipts do |t|
      t.references :platform, null: false, type: :uuid, index: { name: 'idx_bt_billing_notif_receipts_platform' },
                              foreign_key: { to_table: :better_together_platforms }
      t.references :recipient, null: false, type: :uuid, index: { name: 'idx_bt_billing_notif_receipts_recipient' },
                               foreign_key: { to_table: :better_together_people, on_delete: :cascade }
      t.string :kind, null: false
      t.string :audience, null: false
      t.string :dedupe_key, null: false
    end

    add_index TABLE, %i[platform_id recipient_id kind dedupe_key], unique: true, name: 'idx_bt_billing_notif_receipts_unique'
  end

  def down
    drop_table TABLE if table_exists?(TABLE)
  end
end
