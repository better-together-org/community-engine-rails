# frozen_string_literal: true

# Adds creator association to platforms
class AddCreatorToBetterTogetherPlatforms < ActiveRecord::Migration[7.2]
  def change
    change_table :better_together_platforms do |t|
      t.bt_creator :better_together_platforms
    end
  end
end
