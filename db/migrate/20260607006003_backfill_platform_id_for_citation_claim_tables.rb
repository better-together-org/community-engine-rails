# frozen_string_literal: true

# Phase 8 — Backfill Citations and Claims from polymorphic parents (per type),
# EvidenceLinks from Claims, Joatu::ResponseLinks from source (Offer/Request).
class BackfillPlatformIdForCitationClaimTables < ActiveRecord::Migration[7.2] # rubocop:todo Metrics/ClassLength
  # Platforms are excluded: Platform IS the platform — they have no platform_id column.
  # Platform citations/claims are handled separately below using p.id directly.
  CITEABLE_PARENT_MAP = [
    ["BetterTogether::Page",      "better_together_pages"],
    ["BetterTogether::Post",      "better_together_posts"],
    ["BetterTogether::Event",     "better_together_events"],
    ["BetterTogether::Agreement", "better_together_agreements"]
  ].freeze

  def up # rubocop:todo Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    if column_exists?(:better_together_citations, :platform_id)
      CITEABLE_PARENT_MAP.each do |type_name, parent_table|
        execute <<~SQL
          UPDATE better_together_citations c
          SET    platform_id = p.platform_id
          FROM   #{parent_table} p
          WHERE  c.citeable_type = #{quote(type_name)}
            AND  c.citeable_id   = p.id
            AND  c.platform_id   IS NULL
            AND  p.platform_id   IS NOT NULL
        SQL
      end

      # Platform citations: Platform IS the platform, so use p.id directly.
      execute <<~SQL
        UPDATE better_together_citations c
        SET    platform_id = p.id
        FROM   better_together_platforms p
        WHERE  c.citeable_type = #{quote('BetterTogether::Platform')}
          AND  c.citeable_id   = p.id
          AND  c.platform_id   IS NULL
      SQL
    end

    if column_exists?(:better_together_claims, :platform_id)
      CITEABLE_PARENT_MAP.each do |type_name, parent_table|
        execute <<~SQL
          UPDATE better_together_claims cl
          SET    platform_id = p.platform_id
          FROM   #{parent_table} p
          WHERE  cl.claimable_type = #{quote(type_name)}
            AND  cl.claimable_id   = p.id
            AND  cl.platform_id    IS NULL
            AND  p.platform_id     IS NOT NULL
        SQL
      end

      # Platform claims: same pattern
      execute <<~SQL
        UPDATE better_together_claims cl
        SET    platform_id = p.id
        FROM   better_together_platforms p
        WHERE  cl.claimable_type = #{quote('BetterTogether::Platform')}
          AND  cl.claimable_id   = p.id
          AND  cl.platform_id    IS NULL
      SQL
    end

    # EvidenceLink: inherit from Claim
    if column_exists?(:better_together_evidence_links, :platform_id)
      execute <<~SQL
        UPDATE better_together_evidence_links el
        SET    platform_id = cl.platform_id
        FROM   better_together_claims cl
        WHERE  el.claim_id    = cl.id
          AND  el.platform_id IS NULL
          AND  cl.platform_id IS NOT NULL
      SQL
    end

    # Joatu::ResponseLink: source is Offer or Request (separate tables, not a combined view)
    if column_exists?(:better_together_joatu_response_links, :platform_id)
      [
        ["BetterTogether::Joatu::Offer",   "better_together_joatu_offers"],
        ["BetterTogether::Joatu::Request", "better_together_joatu_requests"]
      ].each do |type_name, src_table|
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

    # Host platform fallback for Citations, Claims, EvidenceLinks, ResponseLinks
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    %w[
      better_together_citations
      better_together_claims
      better_together_evidence_links
      better_together_joatu_response_links
    ].each do |table|
      next unless column_exists?(table, :platform_id)

      execute <<~SQL
        UPDATE #{table} SET platform_id = #{quote(host_platform_id)}
        WHERE platform_id IS NULL
      SQL
    end
  end

  def down
    %w[
      better_together_citations
      better_together_claims
      better_together_evidence_links
      better_together_joatu_response_links
    ].each do |table|
      next unless column_exists?(table, :platform_id)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end
end
