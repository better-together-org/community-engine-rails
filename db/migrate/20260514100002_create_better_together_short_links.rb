# frozen_string_literal: true

class CreateBetterTogetherShortLinks < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_short_links)

    create_bt_table :short_links do |t|
      t.string  :code,        null: false
      t.string  :target_url,  null: false
      t.string  :status,      null: false, default: 'active'
      t.datetime :expires_at
      t.integer  :click_count, null: false, default: 0

      # Polymorphic CE content association — used by Phase 2 Shortlinkable concern
      t.string :linkable_type
      t.uuid   :linkable_id

      t.references :platform, null: false, type: :uuid,
                              foreign_key: { to_table: :better_together_platforms },
                              index: false

      t.index %i[platform_id code], unique: true,
                                    name: 'index_better_together_short_links_on_platform_and_code'
      t.index %i[linkable_type linkable_id],
              name: 'index_better_together_short_links_on_linkable',
              unique: true
      t.index :platform_id,
              name: 'index_better_together_short_links_on_platform_id'
    end
  end
end
