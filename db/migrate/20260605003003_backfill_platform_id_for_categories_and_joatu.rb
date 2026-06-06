# frozen_string_literal: true

# Phase 3 — Backfill platform_id for categories, categorizations, and joatu exchanges.
# All existing records assigned to the host platform (single-platform baseline).
class BackfillPlatformIdForCategoriesAndJoatu < ActiveRecord::Migration[7.2]
  TABLES = %w[
    better_together_categories
    better_together_categorizations
    better_together_joatu_requests
    better_together_joatu_offers
    better_together_joatu_agreements
  ].freeze

  def up
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    TABLES.each do |table|
      next unless table_exists?(table)

      execute <<~SQL
        UPDATE #{table}
        SET    platform_id = '#{host_platform_id}'
        WHERE  platform_id IS NULL
      SQL
    end
  end

  def down
    TABLES.each do |table|
      next unless table_exists?(table)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end
end
