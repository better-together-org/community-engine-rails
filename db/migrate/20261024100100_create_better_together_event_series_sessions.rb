# frozen_string_literal: true

# Which events are the sessions of which series. A session belongs to one series; sessions on the same day are fine.
class CreateBetterTogetherEventSeriesSessions < ActiveRecord::Migration[8.1]
  TABLE = :better_together_event_series_sessions

  def up
    return if table_exists?(TABLE)

    create_bt_table :event_series_sessions do |t|
      t.bt_references :series, target_table: :better_together_events, null: false,
                               index: { name: 'bt_event_series_sessions_by_series' }
      t.bt_references :session, target_table: :better_together_events, null: false, index: false
      t.integer :position, null: false, default: 0
      t.index :session_id, unique: true, name: 'bt_event_series_sessions_by_session'
    end
  end

  def down
    drop_table TABLE, if_exists: true
  end
end
