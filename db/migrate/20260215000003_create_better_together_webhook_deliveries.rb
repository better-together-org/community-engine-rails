# frozen_string_literal: true

# Creates the webhook_deliveries table for tracking outbound webhook delivery attempts
class CreateBetterTogetherWebhookDeliveries < ActiveRecord::Migration[7.2]
  def change
    create_bt_table :webhook_deliveries do |t|
      t.bt_references :webhook_endpoint, null: false
      t.string :event, null: false
      t.jsonb :payload, null: false, default: {}
      t.integer :response_code
      t.text :response_body
      t.datetime :delivered_at
      t.integer :attempts, null: false, default: 0
      t.string :status, null: false, default: 'pending'

      t.index :event
      t.index :status
      t.index :delivered_at
    end
  end
end
