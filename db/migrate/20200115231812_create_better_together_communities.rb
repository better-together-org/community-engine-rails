# frozen_string_literal: true

# Creates communities table
class CreateBetterTogetherCommunities < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :communities do |t|
      t.bt_identifier
      t.bt_host
      t.bt_protected
      t.bt_privacy('community')
      t.bt_slug

      # Reference to the better_together_people table for the creator
      t.bt_references :creator, target_table: :better_together_people, index: { name: 'by_creator' }, null: true

      # Standard columns like lock_version and timestamps are added by create_bt_table
    end
  end
end
