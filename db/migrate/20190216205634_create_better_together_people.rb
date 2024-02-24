# frozen_string_literal: true

# Creates people table
class CreateBetterTogetherPeople < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :people do |t|
      t.bt_emoji_name
      t.bt_emoji_description
      t.string :slug, null: false, index: { unique: true }
    end
  end
end
