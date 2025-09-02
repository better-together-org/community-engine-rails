# frozen_string_literal: true

class AddEventRefToCalendarEntries < ActiveRecord::Migration[7.1] # rubocop:disable Style/Documentation
  def change
    change_table :better_together_calendar_entries do |t|
      t.bt_references :event, null: false, index: { name: 'bt_calendar_entries_by_event' }
    end

    add_index :better_together_calendar_entries, %i[calendar_id event_id], unique: true, name: 'by_calendar_and_event'
  end
end
