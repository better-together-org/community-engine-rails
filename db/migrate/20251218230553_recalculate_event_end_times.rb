# frozen_string_literal: true

# Recalculates and sets ends_at for events that have starts_at and duration_minutes but no ends_at
class RecalculateEventEndTimes < ActiveRecord::Migration[8.0]
  def up
    puts "Recalculating event end times for events with duration but no end time..."

    # Execute the rake task that calculates ends_at from starts_at + duration_minutes
    # This ensures events are properly categorized as ongoing vs past
    begin
      Rake::Task['better_together:events:recalculate_end_times'].invoke
    rescue RuntimeError
      Rake::Task['app:better_together:events:recalculate_end_times'].invoke
    end
  end

  def down
    # This migration is not reversible since we can't know which events
    # originally had ends_at set vs which were calculated
    raise ActiveRecord::IrreversibleMigration,
          "Cannot reverse recalculation of event end times"
  end
end
