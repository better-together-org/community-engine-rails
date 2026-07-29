# frozen_string_literal: true

class CreateBetterTogetherInboundEmailReplyTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :better_together_inbound_email_reply_tokens, id: :uuid do |t|
      t.string :token, null: false
      t.references :recipient, null: false, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.references :repliable, polymorphic: true, null: false, type: :uuid
      t.references :platform, type: :uuid, foreign_key: { to_table: :better_together_platforms }
      t.string :notification_type, null: false
      t.datetime :expires_at
      t.datetime :consumed_at

      t.timestamps
    end

    add_index :better_together_inbound_email_reply_tokens, :token, unique: true
  end
end
