# frozen_string_literal: true

# Phase 8 — Backfill communities.platform_id from the platform record.
class BackfillPlatformIdForCommunities < ActiveRecord::Migration[7.2]
  def up
    return unless column_exists?(:better_together_communities, :platform_id)

    # Host platform catch-all for root communities
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
