# frozen_string_literal: true

# Phase 7 — Backfill people.platform_id from the platform whose host community matches
# the person's community_id, with membership and host-platform fallbacks.
class BackfillPlatformIdForPeople < ActiveRecord::Migration[7.2]
  def up
    return unless column_exists?(:better_together_people, :platform_id)

    # Step 1: match via platform.community_id = person.community_id
    execute <<~SQL
      UPDATE better_together_people p
      SET    platform_id = pl.id
      FROM   better_together_platforms pl
      WHERE  pl.community_id = p.community_id
        AND  p.platform_id IS NULL
    SQL

    # Step 2: fallback via first active PersonPlatformMembership (DISTINCT ON keeps only
    # one platform per person — the one with the lowest joinable_id to be deterministic)
    execute <<~SQL
      UPDATE better_together_people p
      SET    platform_id = ppm.joinable_id
      FROM   (
        SELECT DISTINCT ON (member_id)
               member_id, joinable_id
        FROM   better_together_person_platform_memberships
        WHERE  status = 'active'
        ORDER  BY member_id, joinable_id
      ) ppm
      WHERE  ppm.member_id = p.id
        AND  p.platform_id IS NULL
    SQL

    # Step 3: host platform catch-all
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    execute <<~SQL
      UPDATE better_together_people
      SET    platform_id = #{quote(host_platform_id)}
      WHERE  platform_id IS NULL
    SQL
  end

  def down
    return unless column_exists?(:better_together_people, :platform_id)

    execute "UPDATE better_together_people SET platform_id = NULL"
  end
end
