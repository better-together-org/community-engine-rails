# frozen_string_literal: true

# adds a notifications preferences column to track and store message notification preferences
class AddNotificationPreferencesToBetterTogetherPeople < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_people, :notification_preferences, :jsonb, null: false, default: {}
  end
end
