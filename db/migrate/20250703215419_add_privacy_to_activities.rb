# frozen_string_literal: true

class AddPrivacyToActivities < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_activities, &:bt_privacy
  end
end
