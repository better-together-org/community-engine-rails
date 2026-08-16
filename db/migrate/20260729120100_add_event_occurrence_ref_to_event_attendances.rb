# frozen_string_literal: true

# Adds an optional per-occurrence dimension to event attendance. `event_id`
# stays required (series context always applies); `event_occurrence_id` is
# nullable — nil means "series-wide" attendance (today's only behavior),
# present means "attendance for this one specific session."
class AddEventOccurrenceRefToEventAttendances < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_event_attendances)

    unless column_exists?(:better_together_event_attendances, :event_occurrence_id)
      change_table :better_together_event_attendances do |t|
        t.bt_references :event_occurrence, null: true, index: { name: 'bt_event_attendance_by_occurrence' }
      end
    end

    return unless index_name_exists?(:better_together_event_attendances, 'by_event_and_person')

    remove_index :better_together_event_attendances, name: 'by_event_and_person'
    # NOTE: Postgres unique indexes treat NULL as distinct from every other NULL, so this
    # index alone cannot block two series-wide (event_occurrence_id: nil) attendances for
    # the same (event, person) — the model's uniqueness validation is the authoritative
    # guard for that case; this index protects the common, non-null case at the DB layer.
    add_index :better_together_event_attendances, %i[event_id person_id event_occurrence_id],
              unique: true, name: 'by_event_person_and_occurrence'
  end

  def down
    return unless table_exists?(:better_together_event_attendances)

    if index_name_exists?(:better_together_event_attendances, 'by_event_person_and_occurrence')
      remove_index :better_together_event_attendances, name: 'by_event_person_and_occurrence'
      add_index :better_together_event_attendances, %i[event_id person_id], unique: true, name: 'by_event_and_person'
    end

    return unless column_exists?(:better_together_event_attendances, :event_occurrence_id)

    remove_column :better_together_event_attendances, :event_occurrence_id
  end
end
