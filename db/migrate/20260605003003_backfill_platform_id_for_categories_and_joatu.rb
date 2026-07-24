# frozen_string_literal: true

# Phase 3 — Backfill platform_id for categories, categorizations, and joatu exchanges.
#
# Categories have no owning record (shared taxonomy) and are assigned to the
# host platform directly. Categorizations, joatu offers/requests, and joatu
# agreements are derived from their real owner first, falling back to the
# host platform only when no owner can be determined.
class BackfillPlatformIdForCategoriesAndJoatu < ActiveRecord::Migration[7.2]
  HOST_ONLY_TABLES = %w[
    better_together_categories
  ].freeze

  CATEGORIZABLE_TYPES = {
    'BetterTogether::Post' => 'better_together_posts',
    'BetterTogether::Page' => 'better_together_pages',
    'BetterTogether::Event' => 'better_together_events'
  }.freeze

  def up
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    HOST_ONLY_TABLES.each { |table| backfill_host_only(table, host_platform_id) }

    backfill_categorizations(host_platform_id)
    backfill_from_creator('better_together_joatu_offers', host_platform_id)
    backfill_from_creator('better_together_joatu_requests', host_platform_id)
    backfill_joatu_agreements(host_platform_id)
  end

  def down
    (HOST_ONLY_TABLES + %w[
      better_together_categorizations
      better_together_joatu_offers
      better_together_joatu_requests
      better_together_joatu_agreements
    ]).each do |table|
      next unless table_exists?(table)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end

  private

  def backfill_host_only(table, host_platform_id)
    return unless table_exists?(table)

    execute <<~SQL
      UPDATE #{quote_table_name(table)}
      SET    platform_id = #{quote(host_platform_id)}
      WHERE  platform_id IS NULL
    SQL
  end

  def backfill_categorizations(host_platform_id)
    return unless table_exists?('better_together_categorizations')

    CATEGORIZABLE_TYPES.each do |type, owner_table|
      next unless table_exists?(owner_table)

      execute <<~SQL
        UPDATE better_together_categorizations cz
        SET    platform_id = owner.platform_id
        FROM   #{owner_table} owner
        WHERE  cz.categorizable_type = #{quote(type)}
          AND  cz.categorizable_id = owner.id
          AND  cz.platform_id IS NULL
          AND  owner.platform_id IS NOT NULL
      SQL
    end

    execute <<~SQL
      UPDATE better_together_categorizations
      SET    platform_id = #{quote(host_platform_id)}
      WHERE  platform_id IS NULL
    SQL
  end

  def backfill_from_creator(table, host_platform_id)
    return unless table_exists?(table)

    execute <<~SQL
      UPDATE #{quote_table_name(table)} rec
      SET    platform_id = ppm.joinable_id
      FROM   better_together_people p
      JOIN   better_together_person_platform_memberships ppm
        ON   p.id = ppm.member_id
      WHERE  rec.creator_id = p.id
        AND  rec.platform_id IS NULL
        AND  ppm.joinable_id IS NOT NULL
    SQL

    execute <<~SQL
      UPDATE #{quote_table_name(table)}
      SET    platform_id = #{quote(host_platform_id)}
      WHERE  platform_id IS NULL
    SQL
  end

  def backfill_joatu_agreements(host_platform_id)
    return unless table_exists?('better_together_joatu_agreements')

    # Derive from the offer first (offers are already backfilled above by this point).
    execute <<~SQL
      UPDATE better_together_joatu_agreements ja
      SET    platform_id = o.platform_id
      FROM   better_together_joatu_offers o
      WHERE  ja.offer_id = o.id
        AND  ja.platform_id IS NULL
        AND  o.platform_id IS NOT NULL
    SQL

    execute <<~SQL
      UPDATE better_together_joatu_agreements
      SET    platform_id = #{quote(host_platform_id)}
      WHERE  platform_id IS NULL
    SQL
  end
end
