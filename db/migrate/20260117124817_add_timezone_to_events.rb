# frozen_string_literal: true

# Adds timezone column to events and backfills existing records
class AddTimezoneToEvents < ActiveRecord::Migration[7.2]
  def up
    unless column_exists?(:better_together_events, :timezone)
      add_column :better_together_events, :timezone, :string, default: 'UTC', null: false
    end
    add_index :better_together_events, :timezone unless index_exists?(:better_together_events, :timezone)

    backfill_event_timezones
  end

  def down
    remove_index :better_together_events, :timezone if index_exists?(:better_together_events, :timezone)
    remove_column :better_together_events, :timezone if column_exists?(:better_together_events, :timezone)
  end

  private

  # Plain SQL: the Event model fails to load on a from-zero run (its enums need later columns).
  def backfill_event_timezones
    return unless column_exists?(:better_together_platforms, :time_zone)

    zone = select_value('SELECT time_zone FROM better_together_platforms WHERE host = TRUE LIMIT 1')
    return if zone.blank? || zone == 'UTC'

    say "Backfilling events with timezone: #{zone}"
    execute "UPDATE better_together_events SET timezone = #{quote(zone)}"
  end
end
