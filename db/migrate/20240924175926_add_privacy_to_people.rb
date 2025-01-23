# frozen_string_literal: true

class AddPrivacyToPeople < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    change_table :better_together_people, &:bt_privacy
  end
end
