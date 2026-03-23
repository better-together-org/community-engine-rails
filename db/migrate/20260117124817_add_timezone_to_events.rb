# frozen_string_literal: true

# Adds timezone column to events and backfills existing records
class AddTimezoneToEvents < ActiveRecord::Migration[7.2]
  def up
    # Add timezone column with sensible default
    add_column :better_together_events, :timezone, :string, default: 'UTC', null: false
    add_index :better_together_events, :timezone

    # Backfill existing events with platform timezone
    backfill_event_timezones
  end

  def down
    remove_column :better_together_events, :timezone
  end

  private

  def backfill_event_timezones
    # Get platform timezone (safe for multi-tenancy)
    platform = BetterTogether::Platform.find_by(host: true)
    default_timezone = platform&.time_zone || 'UTC'

    say "Backfilling #{BetterTogether::Event.count} events with timezone: #{default_timezone}"

    # Update in batches to avoid memory issues
    BetterTogether::Event.find_each(batch_size: 100) do |event|
      event.update_column(:timezone, default_timezone)
    rescue StandardError => e
      # Log error but continue migration
      say "Failed to set timezone for event #{event.id}: #{e.message}", true

      # Fall back to UTC for this event
      begin
        event.update_column(:timezone, 'UTC')
      rescue StandardError
        nil
      end
    end

    say "Backfill complete. Verify with: BetterTogether::Event.where(timezone: nil).count"
  end
end
