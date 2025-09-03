# frozen_string_literal: true

# Creates table to track and store Better Together Seed records
class CreateBetterTogetherSeeds < ActiveRecord::Migration[7.1]
  def change # rubocop:todo Metrics/MethodLength
    drop_table :better_together_seeds if table_exists?(:better_together_seeds)

    create_bt_table :seeds, id: :uuid do |t|
      t.string :type, null: false, default: 'BetterTogether::Seed'

      t.bt_references :seedable, polymorphic: true, null: true, index: 'by_seed_seedable'

      t.bt_creator
      t.bt_identifier
      t.bt_privacy

      t.string :version, null: false
      t.string :created_by, null: false
      t.datetime :seeded_at, null: false
      t.text :description, null: false

      t.jsonb :origin, null: false # Full origin block (platforms, contributors, license, usage_notes)
      t.jsonb :payload, null: false # Full wizard/page_template/content_block data
    end

    add_index :better_together_seeds, %i[type identifier], unique: true
    # JSONB indexes - GIN index for fast key lookups inside origin and payload
    add_index :better_together_seeds, :origin, using: :gin
    add_index :better_together_seeds, :payload, using: :gin
  end
end
