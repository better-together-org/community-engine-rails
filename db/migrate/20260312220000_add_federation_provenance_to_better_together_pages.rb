# frozen_string_literal: true

class AddFederationProvenanceToBetterTogetherPages < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:better_together_pages, :platform_id)
      add_reference :better_together_pages, :platform, type: :uuid, foreign_key: { to_table: :better_together_platforms }
    end
    add_column :better_together_pages, :source_id, :string unless column_exists?(:better_together_pages, :source_id)
    add_column :better_together_pages, :source_updated_at, :datetime unless column_exists?(:better_together_pages, :source_updated_at)
    add_column :better_together_pages, :last_synced_at, :datetime unless column_exists?(:better_together_pages, :last_synced_at)

    return if index_name_exists?(:better_together_pages, 'index_bt_pages_on_platform_and_source_id')

    add_index :better_together_pages, %i[platform_id source_id],
              unique: true,
              where: '(source_id IS NOT NULL)',
              name: 'index_bt_pages_on_platform_and_source_id'
  end
end
