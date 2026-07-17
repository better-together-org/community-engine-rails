# frozen_string_literal: true

# Metrics::Download/PageView already have platform_id NOT NULL, populated at creation
# time from the *viewer's* current platform context (TrackDownloadJob/TrackPageViewJob),
# not from the content actually downloaded/viewed. For federated/cross-platform content
# this mismatches the real owner. This migration re-derives (overwrites, not just fills
# NULLs) any row where platform_id disagrees with its polymorphic owner's real platform,
# reusing the same content-type mapping as the original
# 20260330172000_add_platform_and_logged_in_to_metrics.rb backfill.
class CorrectPlatformIdMismatchForDownloadsAndPageViews < ActiveRecord::Migration[7.2]
  CONTENT_TYPES = {
    'BetterTogether::Post' => 'better_together_posts',
    'BetterTogether::Page' => 'better_together_pages',
    'BetterTogether::Event' => 'better_together_events'
  }.freeze

  def up
    correct_mismatches(:better_together_metrics_downloads, 'downloadable_type', 'downloadable_id')
    correct_mismatches(:better_together_metrics_page_views, 'pageable_type', 'pageable_id')
  end

  def down
    # Corrective re-derivation has no meaningful inverse — the pre-migration values
    # were the bug being fixed, not a state worth restoring.
  end

  private

  def correct_mismatches(table, type_col, id_col)
    return unless column_exists?(table, :platform_id)

    CONTENT_TYPES.each do |type, owner_table|
      execute <<~SQL.squish
        UPDATE #{quote_table_name(table)} m
        SET platform_id = owner.platform_id
        FROM #{owner_table} owner
        WHERE m.#{type_col} = #{quote(type)}
          AND m.#{id_col} = owner.id
          AND owner.platform_id IS NOT NULL
          AND m.platform_id != owner.platform_id
      SQL
    end
  end
end
