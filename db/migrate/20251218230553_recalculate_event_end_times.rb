# frozen_string_literal: true

# Recalculates and sets ends_at for events that have starts_at and duration_minutes but no ends_at
class RecalculateEventEndTimes < ActiveRecord::Migration[7.2]
  def up
    table = :better_together_events
    return unless table_exists?(table)
    return unless %i[starts_at duration_minutes ends_at].all? { |c| column_exists?(table, c) }

    say 'Recalculating event end times for events with duration but no end time...'

    # Plain SQL (the rake task needs the app model and is not loaded on a from-zero run).
    execute <<~SQL.squish
      UPDATE better_together_events
      SET ends_at = starts_at + (duration_minutes * INTERVAL '1 minute')
      WHERE starts_at IS NOT NULL AND duration_minutes IS NOT NULL AND ends_at IS NULL
    SQL
  end

  def down
    # This migration is not reversible since we can't know which events
    # originally had ends_at set vs which were calculated
    raise ActiveRecord::IrreversibleMigration,
          "Cannot reverse recalculation of event end times"
  end
end
