# frozen_string_literal: true

class CreateBetterTogetherSeeds < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:better_together_seeds)

    create_table :better_together_seeds, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.string :type, null: false, default: 'BetterTogether::Seed'
      t.string :seedable_type
      t.uuid :seedable_id
      t.uuid :creator_id
      t.string :identifier, null: false
      t.string :privacy, null: false, default: 'private'
      t.string :version, null: false
      t.string :created_by, null: false
      t.datetime :seeded_at, null: false
      t.text :description, null: false
      t.jsonb :origin, null: false, default: {}
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    add_index :better_together_seeds, :creator_id, name: 'by_better_together_seeds_creator'
    add_index :better_together_seeds, :privacy, name: 'by_better_together_seeds_privacy'
    add_index :better_together_seeds, :identifier, unique: true
    add_index :better_together_seeds, %i[type identifier], unique: true
    add_index :better_together_seeds, %i[seedable_type seedable_id], name: 'index_better_together_seeds_on_seedable'
    add_index :better_together_seeds, :origin, using: :gin
    add_index :better_together_seeds, :payload, using: :gin
  end
end
