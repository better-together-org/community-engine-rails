# frozen_string_literal: true

# Metrics::Share.platform_id is NOT NULL, populated at creation time from the
# *viewer's* current platform context (SharesController -> TrackShareJob), not
# from the content actually shared. For federated/cross-platform content this
# mismatches the real owner — the exact bug already fixed for Download/PageView.
# Re-derives (overwrites, not just fills NULLs) any row where platform_id
# disagrees with its polymorphic shareable owner's real platform, reusing the
# same content-type mapping as 20260330172000_add_platform_and_logged_in_to_metrics.rb.
class CorrectPlatformIdMismatchForMetricsShares < ActiveRecord::Migration[7.2]
  CONTENT_TYPES = {
    'BetterTogether::Post' => 'better_together_posts',
    'BetterTogether::Page' => 'better_together_pages',
    'BetterTogether::Event' => 'better_together_events'
  }.freeze

  def up
    return unless column_exists?(:better_together_metrics_shares, :platform_id)

    CONTENT_TYPES.each do |type, owner_table|
      execute <<~SQL.squish
        UPDATE better_together_metrics_shares m
        SET platform_id = owner.platform_id
        FROM #{owner_table} owner
        WHERE m.shareable_type = #{quote(type)}
          AND m.shareable_id = owner.id
          AND owner.platform_id IS NOT NULL
          AND m.platform_id != owner.platform_id
      SQL
    end
  end

  def down
    # Corrective re-derivation has no meaningful inverse — the pre-migration
    # values were the bug being fixed, not a state worth restoring.
  end
end
