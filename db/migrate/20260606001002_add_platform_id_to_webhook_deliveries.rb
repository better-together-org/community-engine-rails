# frozen_string_literal: true

# Phase 5 — WebhookDelivery isolation (denormalised from endpoint for query performance).
# Nullable; backfill inherits platform_id from the parent WebhookEndpoint.
class AddPlatformIdToWebhookDeliveries < ActiveRecord::Migration[7.2]
  def change
    add_reference :better_together_webhook_deliveries, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
