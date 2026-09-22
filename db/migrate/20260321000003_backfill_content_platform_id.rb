# frozen_string_literal: true

# Backfill platform_id on content tables (posts, pages, events) to the host platform
# for all records that pre-date the multi-tenant federation provenance migrations.
#
# These columns were added as nullable in:
#   20260312213000_add_federation_provenance_to_better_together_posts.rb
#   20260312220000_add_federation_provenance_to_better_together_pages.rb
#   20260312223000_add_federation_provenance_to_better_together_events.rb
#
# In a fresh greenfield deployment this is a no-op.
# In an upgrade of an existing CE instance it assigns every locally-authored
# record (platform_id IS NULL) to the host platform so the federation
# provenance queries resolve correctly.
class BackfillContentPlatformId < ActiveRecord::Migration[7.2]
  TABLES = %w[
    better_together_posts
    better_together_pages
    better_together_events
  ].freeze

  def up
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    TABLES.each do |table|
      # Derive platform_id from the record's own creator's platform membership first,
      # so any cross-tenant content already present at migration time (e.g. an
      # in-progress federation setup) isn't silently reassigned to the host.
      execute <<~SQL
        UPDATE #{table} rec
        SET    platform_id = ppm.joinable_id
        FROM   better_together_people p
        JOIN   better_together_person_platform_memberships ppm
          ON   p.id = ppm.member_id
        WHERE  rec.creator_id = p.id
          AND  rec.platform_id IS NULL
          AND  ppm.joinable_id IS NOT NULL
      SQL

      execute <<~SQL
        UPDATE #{table}
        SET    platform_id = '#{host_platform_id}'
        WHERE  platform_id IS NULL
      SQL
    end
  end

  def down
    # This backfill is not reversible without a prior snapshot of which records
    # had a NULL platform_id.  Reversing would require manually clearing
    # platform_id for all records that were set in the up step, which is
    # destructive if any of those records have since been updated.
    raise ActiveRecord::IrreversibleMigration
  end
end
