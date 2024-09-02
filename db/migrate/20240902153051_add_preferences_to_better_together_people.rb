# frozen_string_literal: true

class AddPreferencesToBetterTogetherPeople < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_people, :preferences, :jsonb, null: false, default: {}
  end
end
