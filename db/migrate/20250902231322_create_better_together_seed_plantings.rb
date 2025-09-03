# frozen_string_literal: true

# Creates table to track Better Together Seed planting operations
class CreateBetterTogetherSeedPlantings < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :seed_plantings do |t|
      t.string :status, null: false, default: 'pending'
      t.text :source
      t.string :planting_type
      t.bt_creator
      t.bt_references :seed, target_table: :better_together_seeds, null: true
      t.text :error_message
      t.jsonb :result
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :metadata, null: false, default: '{}'

      t.index :status
      t.index :planting_type
      t.index :started_at
      t.index :completed_at
    end
  end
end
