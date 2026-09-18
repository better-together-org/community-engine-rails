# frozen_string_literal: true

# Denormalized "when does this event next occur" scalar, kept fresh via
# Event#refresh_next_occurrence_at! (on save/callback) and
# EventNextOccurrenceRefreshScanJob (hourly, for the passage of time itself).
# Lets the events index and calendar upcoming/past lists stay pure SQL
# instead of running IceCube math per row on every request.
class AddNextOccurrenceAtToBetterTogetherEvents < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_events)
    return if column_exists?(:better_together_events, :next_occurrence_at)

    add_column :better_together_events, :next_occurrence_at, :datetime
    add_index :better_together_events, :next_occurrence_at, name: 'bt_events_by_next_occurrence_at'

    # Backfill existing rows so the column is never silently nil for
    # already-persisted events: non-recurring events use their own starts_at;
    # recurring events get their true next occurrence.
    say_with_time 'Backfilling next_occurrence_at for existing events' do
      BetterTogether::Event.reset_column_information
      BetterTogether::Event.find_each do |event|
        event.refresh_next_occurrence_at!
      rescue StandardError => e
        Rails.logger.error("Failed to backfill next_occurrence_at for event #{event.id}: #{e.message}")
      end
    end
  end

  def down
    return unless table_exists?(:better_together_events)
    return unless column_exists?(:better_together_events, :next_occurrence_at)

    remove_column :better_together_events, :next_occurrence_at
  end
end
