# frozen_string_literal: true

# Create event attendance table for RSVP functionality
class CreateBetterTogetherEventAttendances < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :event_attendances do |t|
      t.bt_references :event, null: false, index: { name: 'bt_event_attendance_by_event' }
      t.bt_references :person, null: false, index: { name: 'bt_event_attendance_by_person' }
      t.string :status, null: false, default: 'interested'
    end

    add_index :better_together_event_attendances, %i[event_id person_id], unique: true, name: 'by_event_and_person'
  end
end
