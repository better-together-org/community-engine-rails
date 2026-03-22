# frozen_string_literal: true

# Creates table to track blocks between people
class CreateBetterTogetherPersonBlocks < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :person_blocks do |t|
      t.references :blocker, null: false, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.references :blocked, null: false, type: :uuid, foreign_key: { to_table: :better_together_people }

      t.index %i[blocker_id blocked_id], unique: true, name: 'unique_person_blocks'
    end
  end
end
