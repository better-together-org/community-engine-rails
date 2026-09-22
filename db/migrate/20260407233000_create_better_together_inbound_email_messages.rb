# frozen_string_literal: true

class CreateBetterTogetherInboundEmailMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :better_together_inbound_email_messages, id: :uuid do |t|
      t.references :inbound_email, null: false, type: :uuid, foreign_key: { to_table: :action_mailbox_inbound_emails }
      t.string :route_kind, null: false
      t.string :status, null: false, default: 'received'
      t.references :target, polymorphic: true, type: :uuid
      t.references :routed_record, polymorphic: true, type: :uuid
      t.string :message_id, null: false
      t.string :sender_email, null: false
      t.string :sender_name
      t.string :recipient_address, null: false
      t.string :recipient_local_part, null: false
      t.string :recipient_domain, null: false
      t.text :subject
      t.text :body_plain

      t.timestamps
    end

    add_index :better_together_inbound_email_messages, :message_id
    add_index :better_together_inbound_email_messages, %i[route_kind status]
  end
end
