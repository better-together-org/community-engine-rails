# frozen_string_literal: true

# Migration to create recurrences table for polymorphic recurring events
# Supports Events, CalendarEntries, Tasks, and any other schedulable resources
class CreateBetterTogetherRecurrences < ActiveRecord::Migration[7.2]
  def change
    create_table :better_together_recurrences, id: :uuid do |t|
      t.references :schedulable, polymorphic: true, null: false, type: :uuid
      t.text :rule, null: false                    # ice_cube YAML serialization
      t.date :exception_dates, array: true, default: []
      t.date :ends_on                              # Optional recurrence end date
      t.string :frequency                          # daily, weekly, monthly, yearly (for queries)

      t.integer :lock_version, default: 0, null: false
      t.timestamps

      t.index %i[schedulable_type schedulable_id], name: 'index_recurrences_on_schedulable'
      t.index :frequency
      t.index :ends_on
    end
  end
end
