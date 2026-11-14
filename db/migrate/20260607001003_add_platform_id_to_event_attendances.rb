# frozen_string_literal: true

# Phase 6 — Platform isolation for join tables.
# EventAttendance allows cross-platform queries without this column.
class AddPlatformIdToEventAttendances < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_event_attendances, :platform_id)

    add_reference :better_together_event_attendances, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
