# frozen_string_literal: true

# Creates the webhook_endpoints table for outbound webhook subscriptions
class CreateBetterTogetherWebhookEndpoints < ActiveRecord::Migration[7.2]
  def change
    create_bt_table :webhook_endpoints do |t|
      t.string :url, null: false
      t.string :secret, null: false
      t.string :events, array: true, default: [], null: false
      t.boolean :active, null: false, default: true
      t.string :name, null: false
      t.text :description

      t.bt_references :person, null: false
      t.bt_references :oauth_application,
                      target_table: :better_together_oauth_applications,
                      null: true

      t.index :active
      t.index :events, using: :gin
    end
  end
end
