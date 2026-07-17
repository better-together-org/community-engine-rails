# frozen_string_literal: true

# webhook_deliveries.platform_id is a denormalized copy of webhook_endpoint.platform_id,
# but no code path ever actually set it (the model comment claimed otherwise). Backfill
# every existing row from its real endpoint, then tighten to NOT NULL now that the
# model derives it automatically going forward.
class BackfillPlatformIdForBetterTogetherWebhookDeliveries < ActiveRecord::Migration[7.2]
  def up
    return unless column_exists?(:better_together_webhook_deliveries, :platform_id)

    execute <<~SQL
      UPDATE better_together_webhook_deliveries wd
      SET    platform_id = we.platform_id
      FROM   better_together_webhook_endpoints we
      WHERE  wd.webhook_endpoint_id = we.id
        AND  wd.platform_id IS NULL
        AND  we.platform_id IS NOT NULL
    SQL

    remaining_null = execute(
      'SELECT count(*) FROM better_together_webhook_deliveries WHERE platform_id IS NULL'
    ).first&.fetch('count').to_i

    if remaining_null.zero?
      change_column_null :better_together_webhook_deliveries, :platform_id, false
    else
      say "Skipping NOT NULL: #{remaining_null} webhook_deliveries rows still have a NULL " \
          'platform_id (endpoint itself has no platform_id) — leaving nullable.'
    end
  end

  def down
    return unless column_exists?(:better_together_webhook_deliveries, :platform_id)

    change_column_null :better_together_webhook_deliveries, :platform_id, true
  end
end
