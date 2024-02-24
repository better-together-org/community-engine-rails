# frozen_string_literal: true

# Creates communities table
class CreateBetterTogetherCommunities < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :communities do |t|
      t.bt_emoji_name index: { name: 'by_community_name' }
      t.string :slug, null: false, index: { unique: true }
      t.bt_emoji_description index: { name: 'by_community_description' }

      # Reference to the better_together_people table for the creator
      t.bt_references :creator, target_table: :better_together_people, index: { name: 'by_creator' }, null: true

      # Adding privacy column
      t.string :privacy, null: false, default: 'public', limit: 50, index: { name: 'by_community_privacy' }

      # Adding a host boolean column with a unique constraint that only allows one true value
      t.boolean :host, default: false, null: false
      t.index :host, unique: true, where: 'host IS TRUE AND creator_id IS NULL'

      # Standard columns like lock_version and timestamps are added by create_bt_table
    end
  end
end
