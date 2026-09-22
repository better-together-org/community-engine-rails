# frozen_string_literal: true

# Lightweight, lazily-created per-occurrence override for a recurring Event.
# Only created when a specific session is interacted with (RSVP, comment, or
# an organizer override) — most occurrences of a series never get a row.
class CreateBetterTogetherEventOccurrences < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_event_occurrences)

    create_bt_table :event_occurrences do |t|
      t.bt_references :event, null: false, index: { name: 'bt_event_occurrences_by_event' }
      t.date :occurrence_date, null: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean :cancelled, null: false, default: false
    end

    add_index :better_together_event_occurrences, %i[event_id occurrence_date],
              unique: true, name: 'by_event_and_occurrence_date'
  end
end
