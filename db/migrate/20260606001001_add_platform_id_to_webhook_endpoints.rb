# frozen_string_literal: true

# Phase 5 — WebhookEndpoint isolation.
# Nullable; backfill assigns host platform to pre-existing records.
class AddPlatformIdToWebhookEndpoints < ActiveRecord::Migration[7.2]
  def change
    add_reference :better_together_webhook_endpoints, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
