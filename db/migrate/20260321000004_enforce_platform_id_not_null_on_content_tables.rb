# frozen_string_literal: true

# Enforce NOT NULL on platform_id for the three primary content tables.
#
# This is safe to run only AFTER the following backfill migrations have
# succeeded on the target database:
#   20260321000002_backfill_host_platform_memberships.rb
#   20260321000003_backfill_content_platform_id.rb
#
# Those migrations guarantee that every existing post/page/event row has
# a non-NULL platform_id before this constraint is applied.
#
# If any NULLs remain (e.g. the instance has no host platform configured),
# the constraint is skipped with a warning rather than failing hard — the
# operator can re-run after completing platform setup.
#
# noticed_notifications.platform_id is intentionally left nullable because
# notifications may reference record types other than posts/pages/events
# (which have no platform_id), making a NOT NULL constraint there unsound.
class EnforcePlatformIdNotNullOnContentTables < ActiveRecord::Migration[7.2]
  def up
    %i[better_together_posts better_together_pages better_together_events].each do |table|
      null_count = execute("SELECT COUNT(*) FROM #{table} WHERE platform_id IS NULL").first['count'].to_i
      if null_count.positive?
        say "WARNING: #{null_count} row(s) in #{table} still have NULL platform_id " \
            "(no host platform found during backfill). Skipping NOT NULL constraint. " \
            'Re-run after completing platform setup if needed.'
        next
      end

      change_column_null table, :platform_id, false
    end
  end

  def down
    %i[better_together_posts better_together_pages better_together_events].each do |table|
      change_column_null table, :platform_id, true
    end
  end
end
