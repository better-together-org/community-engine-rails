# frozen_string_literal: true

# Phase 8 — Backfill Joatu::ResponseLink platform_id from its source (Offer or Request).
#
# Originally also backfilled Citations/Claims (from their polymorphic parents) and
# EvidenceLinks (from Claims), but those tables and models were removed from this
# release as part of the Evidence-foundation carve-out — see
# docs/developers/systems/pr_1494_scope_consolidation.md.
class BackfillPlatformIdForCitationClaimTables < ActiveRecord::Migration[7.2]
  RESPONSE_LINK_SOURCES = [
    ['BetterTogether::Joatu::Offer',   'better_together_joatu_offers'],
    ['BetterTogether::Joatu::Request', 'better_together_joatu_requests']
  ].freeze

  def up
    return unless column_exists?(:better_together_joatu_response_links, :platform_id)

    backfill_response_links_from_sources
    backfill_remaining_response_links_from_host_platform
  end

  def down
    return unless column_exists?(:better_together_joatu_response_links, :platform_id)

    execute 'UPDATE better_together_joatu_response_links SET platform_id = NULL'
  end

  private

  # Joatu::ResponseLink: source is Offer or Request (separate tables, not a combined view)
  def backfill_response_links_from_sources
    RESPONSE_LINK_SOURCES.each do |type_name, src_table|
      next unless table_exists?(src_table) && column_exists?(src_table, :platform_id)

      execute <<~SQL
        UPDATE better_together_joatu_response_links rl
        SET    platform_id = src.platform_id
        FROM   #{src_table} src
        WHERE  rl.source_type  = #{quote(type_name)}
          AND  rl.source_id    = src.id
          AND  rl.platform_id  IS NULL
          AND  src.platform_id IS NOT NULL
      SQL
    end
  end

  def backfill_remaining_response_links_from_host_platform
    host_platform_id = execute(
      'SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1'
    ).first&.fetch('id')
    return unless host_platform_id

    execute <<~SQL
      UPDATE better_together_joatu_response_links SET platform_id = #{quote(host_platform_id)}
      WHERE platform_id IS NULL
    SQL
  end
end
