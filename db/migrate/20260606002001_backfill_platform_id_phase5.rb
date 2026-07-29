# frozen_string_literal: true

# Phase 5 — Backfill platform_id for all newly scoped model families.
#
# Tables with a real derivable owner are backfilled via join first, falling
# back to the host platform only for records whose owner can't be resolved.
# `better_together_activities` and `better_together_person_blocks` are
# intentionally NOT blanket-defaulted here — Phase 9
# (20260616002001_backfill_platform_id_for_critical_isolation.rb) derives
# both via join later in the campaign; blanket-setting them here first would
# leave nothing NULL for Phase 9's correct join-based logic to act on.
# WebhookDeliveries inherit platform_id from their parent WebhookEndpoint.
class BackfillPlatformIdPhase5 < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  # No derivable owner column — correctly host-default.
  HOST_ONLY_TABLES = %w[
    better_together_oauth_applications
    better_together_wizards
    better_together_person_data_exports
    better_together_person_deletion_requests
  ].freeze

  # table => owner FK column, joined through better_together_people.
  CREATOR_OWNED_TABLES = {
    'better_together_uploads' => 'creator_id',
    'better_together_content_blocks' => 'creator_id',
    'better_together_checklists' => 'creator_id',
    'better_together_webhook_endpoints' => 'person_id'
  }.freeze

  CALL_FOR_INTEREST_INTERESTABLE_TYPES = {
    'BetterTogether::Community' => 'better_together_communities',
    'BetterTogether::Calendar' => 'better_together_calendars',
    'BetterTogether::Event' => 'better_together_events',
    'BetterTogether::Page' => 'better_together_pages'
  }.freeze

  def up
    host_platform_id = fetch_host_platform_id
    return unless host_platform_id

    backfill_host_only_tables(host_platform_id)
    CREATOR_OWNED_TABLES.each { |table, fk| backfill_from_creator(table, fk, host_platform_id) }
    backfill_calls_for_interest(host_platform_id)
    backfill_webhook_deliveries(host_platform_id)
  end

  def down
    (HOST_ONLY_TABLES + CREATOR_OWNED_TABLES.keys + %w[
      better_together_calls_for_interest
      better_together_webhook_deliveries
    ]).each do |table|
      next unless table_exists?(table) && column_exists?(table, :platform_id)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end

  private

  def fetch_host_platform_id
    execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')
  end

  def backfill_host_only_tables(host_platform_id)
    HOST_ONLY_TABLES.each do |table|
      next unless table_exists?(table) && column_exists?(table, :platform_id)

      execute <<~SQL
        UPDATE #{table}
        SET    platform_id = #{quote(host_platform_id)}
        WHERE  platform_id IS NULL
      SQL
    end
  end

  def backfill_from_creator(table, owner_column, host_platform_id)
    return unless table_exists?(table) && column_exists?(table, :platform_id)

    execute <<~SQL
      UPDATE #{table} rec
      SET    platform_id = ppm.joinable_id
      FROM   better_together_people p
      JOIN   better_together_person_platform_memberships ppm
        ON   p.id = ppm.member_id
      WHERE  rec.#{owner_column} = p.id
        AND  rec.platform_id IS NULL
        AND  ppm.joinable_id IS NOT NULL
    SQL

    execute <<~SQL
      UPDATE #{table}
      SET    platform_id = #{quote(host_platform_id)}
      WHERE  platform_id IS NULL
    SQL
  end

  def backfill_calls_for_interest(host_platform_id)
    table = 'better_together_calls_for_interest'
    return unless table_exists?(table) && column_exists?(table, :platform_id)

    CALL_FOR_INTEREST_INTERESTABLE_TYPES.each do |type, owner_table|
      next unless table_exists?(owner_table) && column_exists?(owner_table, :platform_id)

      execute <<~SQL
        UPDATE #{table} cfi
        SET    platform_id = owner.platform_id
        FROM   #{owner_table} owner
        WHERE  cfi.interestable_type = #{quote(type)}
          AND  cfi.interestable_id = owner.id
          AND  cfi.platform_id IS NULL
          AND  owner.platform_id IS NOT NULL
      SQL
    end

    backfill_from_creator(table, 'creator_id', host_platform_id)
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
end
