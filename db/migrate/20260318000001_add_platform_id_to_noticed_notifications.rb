# frozen_string_literal: true

# Adds platform_id to noticed_notifications so notification queries can be
# scoped to the current platform in multi-platform-per-instance deployments.
#
# noticed_notifications is owned by the noticed gem — we extend it via a
# regular migration rather than modifying the gem's own migration.
#
# Backfill strategy: for existing notifications, resolve the platform by
# joining through noticed_events.record → platform.  Records that have a
# platform_id column get their value directly; all others are left nil
# (treated as host-platform notifications). This is done in a separate
# data-fill step below so schema changes and data writes are decoupled.
class AddPlatformIdToNoticedNotifications < ActiveRecord::Migration[7.2]
  def up
    # 1. Add nullable column + index first so the table is still writable.
    unless column_exists?(:noticed_notifications, :platform_id)
      add_reference :noticed_notifications, :platform,
                    type: :uuid,
                    null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    # 2. Backfill via SQL so we avoid loading AR models in a migration.
    #    We join noticed_notifications → noticed_events → the polymorphic
    #    record table when the record has a platform_id column.
    #    For records without platform_id we leave the column NULL and let
    #    application code fall back to Current.platform at runtime.
    execute <<~SQL
      UPDATE noticed_notifications nn
      SET    platform_id = sub.platform_id
      FROM (
        SELECT
          nn2.id AS notification_id,
          COALESCE(
            -- Events whose record is a BetterTogether::Event
            (SELECT e_rec.platform_id
             FROM   better_together_events e_rec
             WHERE  e_rec.id::text = ne.record_id::text
               AND  ne.record_type = 'BetterTogether::Event'
             LIMIT  1),
            -- Events whose record is a BetterTogether::Post
            (SELECT p_rec.platform_id
             FROM   better_together_posts p_rec
             WHERE  p_rec.id::text = ne.record_id::text
               AND  ne.record_type = 'BetterTogether::Post'
             LIMIT  1),
            -- Events whose record is a BetterTogether::Page
            (SELECT pg_rec.platform_id
             FROM   better_together_pages pg_rec
             WHERE  pg_rec.id::text = ne.record_id::text
               AND  ne.record_type = 'BetterTogether::Page'
             LIMIT  1)
          ) AS platform_id
        FROM  noticed_notifications nn2
        JOIN  noticed_events ne ON ne.id = nn2.event_id
        WHERE ne.record_type IN (
          'BetterTogether::Event',
          'BetterTogether::Post',
          'BetterTogether::Page'
        )
      ) sub
      WHERE nn.id = sub.notification_id
        AND sub.platform_id IS NOT NULL
    SQL
  end

  def down
    return unless column_exists?(:noticed_notifications, :platform_id)

    remove_reference :noticed_notifications, :platform,
                     foreign_key: { to_table: :better_together_platforms },
                     index: true
  end
end
