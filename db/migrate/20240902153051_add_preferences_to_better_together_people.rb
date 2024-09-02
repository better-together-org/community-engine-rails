# frozen_string_literal: true

# Adds a preferences jsonb column to track and store dynamic attributes like locale and time zone
class AddPreferencesToBetterTogetherPeople < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_people, :preferences, :jsonb, null: false, default: {}
  end
end
