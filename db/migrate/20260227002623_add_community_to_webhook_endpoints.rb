# frozen_string_literal: true

class AddCommunityToWebhookEndpoints < ActiveRecord::Migration[7.2]
  def change
    add_reference :better_together_webhook_endpoints, :community,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_communities },
                  index: true
  end
end
