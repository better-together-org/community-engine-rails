# frozen_string_literal: true

class AddFederationProvenanceToBetterTogetherEvents < ActiveRecord::Migration[7.2]
  def change
    change_table :better_together_events, bulk: true do |t|
      t.references :platform, type: :uuid, foreign_key: { to_table: :better_together_platforms }
      t.string :source_id
      t.datetime :source_updated_at
      t.datetime :last_synced_at
    end

    add_index :better_together_events, %i[platform_id source_id],
              unique: true,
              where: 'source_id IS NOT NULL',
              name: 'index_bt_events_on_platform_and_source_id'
  end
end
