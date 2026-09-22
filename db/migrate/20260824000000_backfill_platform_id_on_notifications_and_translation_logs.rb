# frozen_string_literal: true

# Best-effort backfill for platform_id columns that were added by prior migrations
# but never populated for existing rows, because the code paths that create these
# records didn't stamp platform_id until a later fix:
#   - noticed_notifications.platform_id (20260318000001_add_platform_id_to_noticed_notifications.rb)
#   - better_together_ai_log_translations.platform_id (20260616009001_add_platform_id_to_phase_13_users_auth_rbac_metrics.rb)
#
# This is deliberately best-effort: rows with no inferable platform stay null. It
# does not change any schema — data only.
class BackfillPlatformIdOnNotificationsAndTranslationLogs < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    backfill_noticed_notifications
    backfill_translation_logs
  end

  def down
    # Irreversible by design — no way to distinguish backfilled rows from rows
    # that already had a platform_id for another reason.
  end

  private

  # For each distinct record_type stamped on noticed_events, if that model's table
  # has its own platform_id column, backfill the matching notifications from it.
  # Skips record_types with no platform_id column (nothing to infer from) and
  # record_types whose model class no longer exists.
  def backfill_noticed_notifications
    return unless table_exists?(:noticed_notifications) && table_exists?(:noticed_events)

    record_types = execute(
      "SELECT DISTINCT record_type FROM noticed_events WHERE record_type IS NOT NULL"
    ).map { |row| row['record_type'] }

    record_types.each { |record_type| backfill_notifications_for_record_type(record_type) }
  end

  def backfill_notifications_for_record_type(record_type)
    klass = record_type.safe_constantize
    return unless klass&.table_exists? && klass.column_names.include?('platform_id')

    record_table = klass.quoted_table_name

    execute(<<~SQL.squish)
      UPDATE noticed_notifications
      SET platform_id = records.platform_id
      FROM noticed_events events
      JOIN #{record_table} records ON records.id = events.record_id
      WHERE noticed_notifications.event_id = events.id
        AND noticed_notifications.platform_id IS NULL
        AND events.record_type = #{quote(record_type)}
        AND records.platform_id IS NOT NULL
    SQL
  end

  # Translation logs have no direct content association to infer a platform from —
  # fall back to the initiator's (Person's) own platform, same as PlatformScoped's
  # own resolution order would for a person-authored record.
  def backfill_translation_logs
    return unless table_exists?(:better_together_ai_log_translations)
    return unless table_exists?(:better_together_people) &&
                  column_exists?(:better_together_people, :platform_id)

    execute(<<~SQL.squish)
      UPDATE better_together_ai_log_translations
      SET platform_id = people.platform_id
      FROM better_together_people people
      WHERE better_together_ai_log_translations.initiator_id = people.id
        AND better_together_ai_log_translations.platform_id IS NULL
        AND people.platform_id IS NOT NULL
    SQL
  end
end
