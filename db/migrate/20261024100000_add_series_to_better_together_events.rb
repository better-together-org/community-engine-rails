# frozen_string_literal: true

# An event can be a series: a parent with no dates of its own that groups the sessions of a run (see
# BetterTogether::EventSeries). The flag is the only thing that marks it.
class AddSeriesToBetterTogetherEvents < ActiveRecord::Migration[8.1]
  TABLE = :better_together_events

  def up
    add_column TABLE, :series, :boolean, null: false, default: false unless column_exists?(TABLE, :series)
    add_index TABLE, :series, name: 'bt_events_by_series' unless index_name_exists?(TABLE, 'bt_events_by_series')
  end

  def down
    remove_index TABLE, name: 'bt_events_by_series' if index_name_exists?(TABLE, 'bt_events_by_series')
    remove_column TABLE, :series if column_exists?(TABLE, :series)
  end
end
