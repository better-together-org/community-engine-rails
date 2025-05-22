# frozen_string_literal: true

# Creates join table between a schedulable record and a calendar
class CreateBetterTogetherCalendarEntries < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :calendar_entries do |t|
      t.bt_references :calendar, target_table: :better_together_calendars
      t.bt_references :schedulable, polymorphic: true

      t.datetime :starts_at, null: false, index: { name: 'bt_calendar_events_by_starts_at' }
      t.datetime :ends_at, index: { name: 'bt_calendar_events_by_ends_at' }

      t.decimal :duration_minutes
    end
  end
end
