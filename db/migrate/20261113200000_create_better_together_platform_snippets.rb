# frozen_string_literal: true

# Per-platform head and body code snippets (WordPress style header and footer scripts) with an
# append-only audit table. Snippets are disabled until a steward enables them.
class CreateBetterTogetherPlatformSnippets < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:better_together_platform_snippets)
      create_bt_table :platform_snippets do |t|
        t.references :platform, null: false, type: :uuid, foreign_key: { to_table: :better_together_platforms }
        t.string :name, null: false
        t.string :location, null: false
        t.string :kind, null: false
        t.text :content
        t.string :src
        t.boolean :enabled, null: false, default: false
        t.integer :position, null: false
        t.string :consent_category, null: false, default: 'none'
        t.string :applies_to, null: false, default: 'all'
        t.text :notes
        t.references :updated_by, type: :uuid, null: true, foreign_key: { to_table: :better_together_people }
      end
    end

    unless index_name_exists?(:better_together_platform_snippets, 'index_bt_platform_snippets_on_platform_location_position')
      add_index :better_together_platform_snippets, %i[platform_id location position],
                name: 'index_bt_platform_snippets_on_platform_location_position'
    end

    return if table_exists?(:better_together_platform_snippet_audits)

    create_bt_table :platform_snippet_audits do |t|
      t.references :platform, null: false, type: :uuid, foreign_key: { to_table: :better_together_platforms }
      t.uuid :snippet_id, null: false, index: true
      t.uuid :actor_id, index: true
      t.string :action, null: false
      t.string :snippet_name
      t.jsonb :change_set, null: false, default: {}
    end
  end
end
