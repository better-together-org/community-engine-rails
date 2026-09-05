# frozen_string_literal: true

# Phase 8 — Backfill communities.platform_id from the platform record.
class BackfillPlatformIdForCommunities < ActiveRecord::Migration[7.2]
  def up
    return unless column_exists?(:better_together_communities, :platform_id)

    # Step 1: derive platform_id from the platform that claims this community as its home
    # (platforms.community_id = communities.id). This covers multi-platform setups where
    # each platform has its own host community.
    execute <<~SQL
      UPDATE better_together_communities c
      SET    platform_id = p.id
      FROM   better_together_platforms p
      WHERE  p.community_id = c.id
        AND  c.platform_id IS NULL
    SQL

    # Step 2: fall back to host platform for communities not claimed by any platform
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    execute <<~SQL
      UPDATE better_together_communities
      SET    platform_id = #{quote(host_platform_id)}
      WHERE  platform_id IS NULL
    SQL
  end

  def down
    return unless column_exists?(:better_together_communities, :platform_id)

    execute "UPDATE better_together_communities SET platform_id = NULL"
  end
end
