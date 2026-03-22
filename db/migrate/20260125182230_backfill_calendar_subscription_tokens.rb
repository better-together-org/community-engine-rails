# frozen_string_literal: true

# Backfill subscription tokens for existing calendars
# Generates encrypted tokens in batches for memory efficiency
class BackfillCalendarSubscriptionTokens < ActiveRecord::Migration[7.2]
  def up
    # Process calendars in batches to avoid memory issues with large datasets
    BetterTogether::Calendar.where(subscription_token: nil).find_each(batch_size: 100) do |calendar|
      # Generate token and save - encryption happens automatically via the model
      calendar.regenerate_subscription_token
      calendar.save!
    end
  end

  def down
    # No need to reverse - leaving tokens in place is harmless
    # They'll be regenerated if needed
  end
end
