# frozen_string_literal: true

# Adds an optional registration url for events
class AddRegistrationUrlToBetterTogetherEvents < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_events do |t|
      t.string :registration_url
    end
  end
end
