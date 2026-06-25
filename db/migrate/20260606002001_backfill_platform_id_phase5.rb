# frozen_string_literal: true

# Phase 5 — Backfill platform_id for all newly scoped model families.
# All existing records are assigned to the host platform (single-platform baseline).
# WebhookDeliveries inherit platform_id from their parent WebhookEndpoint.
class BackfillPlatformIdPhase5 < ActiveRecord::Migration[7.2]
  SIMPLE_TABLES = %w[
    better_together_webhook_endpoints
    better_together_uploads
    better_together_oauth_applications
    better_together_activities
    better_together_content_blocks
    better_together_person_blocks
    better_together_wizards
    better_together_checklists
    better_together_calls_for_interest
    better_together_person_data_exports
    better_together_person_deletion_requests
  ].freeze

  def up
    host_platform_id = fetch_host_platform_id
    return unless host_platform_id

    backfill_simple_tables(host_platform_id)
    backfill_webhook_deliveries(host_platform_id)
  end

  private

  def fetch_host_platform_id
    execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')
  end

  def backfill_simple_tables(host_platform_id)
    SIMPLE_TABLES.each do |table|
      next unless table_exists?(table) && column_exists?(table, :platform_id)

      execute <<~SQL
        UPDATE #{table}
        SET    platform_id = #{quote(host_platform_id)}
        WHERE  platform_id IS NULL
      SQL
    end
  end

  def backfill_webhook_deliveries(host_platform_id)
    return unless table_exists?(:better_together_webhook_deliveries) &&
                  column_exists?(:better_together_webhook_deliveries, :platform_id)

    backfill_deliveries_from_endpoints
    backfill_orphaned_deliveries(host_platform_id)
  end

  def backfill_deliveries_from_endpoints
    execute <<~SQL
      UPDATE better_together_webhook_deliveries wd
      SET    platform_id = we.platform_id
      FROM   better_together_webhook_endpoints we
      WHERE  wd.webhook_endpoint_id = we.id
        AND  wd.platform_id IS NULL
    SQL
  end

  def backfill_orphaned_deliveries(host_platform_id)
    execute <<~SQL
      UPDATE better_together_webhook_deliveries
      SET    platform_id = #{quote(host_platform_id)}
      WHERE  platform_id IS NULL
    SQL
  end

  def down
    (SIMPLE_TABLES + ['better_together_webhook_deliveries']).each do |table|
      next unless table_exists?(table) && column_exists?(table, :platform_id)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end
end
