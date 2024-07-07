# frozen_string_literal: true

# Creates platforms table
class CreateBetterTogetherPlatforms < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :platforms do |t|
      t.bt_identifier
      t.bt_host
      t.bt_protected
      t.bt_primary_community(:platform)
      t.bt_privacy('platform')
      t.bt_slug

      # Adding a unique URL field
      t.string :url, null: false, index: { unique: true }

      t.string :time_zone, null: false

      # Standard columns like lock_version and timestamps are added by create_bt_table
    end
  end
end
