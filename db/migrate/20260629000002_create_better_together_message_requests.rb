# frozen_string_literal: true

class CreateBetterTogetherMessageRequests < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_message_requests)

    create_bt_table :message_requests do |t|
      t.references :sender,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :better_together_people, on_delete: :cascade },
                   index: { name: 'idx_bt_message_requests_sender' }
      t.references :recipient,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :better_together_people, on_delete: :cascade },
                   index: { name: 'idx_bt_message_requests_recipient' }
      t.references :platform,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :better_together_platforms, on_delete: :cascade },
                   index: { name: 'idx_bt_message_requests_platform' }
      t.text :note, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :responded_at
    end

    add_index :better_together_message_requests,
              %i[sender_id recipient_id platform_id],
              name: 'idx_bt_message_requests_sender_recipient_platform'
  end
end
