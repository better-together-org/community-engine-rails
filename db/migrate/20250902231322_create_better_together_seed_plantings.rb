# frozen_string_literal: true

class CreateBetterTogetherSeedPlantings < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:better_together_seed_plantings)

    create_table :better_together_seed_plantings, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.string :status, null: false, default: 'pending'
      t.text :source
      t.string :planting_type, null: false, default: 'seed'
      t.uuid :creator_id
      t.uuid :seed_id
      t.text :error_message
      t.jsonb :result, default: {}
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :metadata, null: false, default: {}
      t.string :privacy, null: false, default: 'private'
      t.timestamps
    end

    add_index :better_together_seed_plantings, :creator_id, name: 'by_better_together_seed_plantings_creator'
    add_index :better_together_seed_plantings, :privacy, name: 'by_better_together_seed_plantings_privacy'
    add_index :better_together_seed_plantings, :seed_id
    add_index :better_together_seed_plantings, :status
    add_index :better_together_seed_plantings, :planting_type
    add_index :better_together_seed_plantings, :started_at
    add_index :better_together_seed_plantings, :completed_at
  end
end
