# frozen_string_literal: true

class AddFederationProvenanceToBetterTogetherPages < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_pages, bulk: true do |t|
      t.references :platform, type: :uuid, foreign_key: { to_table: :better_together_platforms }
      t.string :source_id
      t.datetime :source_updated_at
      t.datetime :last_synced_at
    end

    add_index :better_together_pages, %i[platform_id source_id],
              unique: true,
              where: '(source_id IS NOT NULL)',
              name: 'index_bt_pages_on_platform_and_source_id'
  end
end
