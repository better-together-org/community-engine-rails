# This migration comes from better_together (originally 20241031213648)
class AddAwesomeNestedSetColumnsToBetterTogetherNavigationItems < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_navigation_items do |t|
      t.integer :lft, null: false, index: true, default: 0
      t.integer :rgt, null: false, index: true, default: 0

      # optional fields
      t.integer :depth, null: false, default: 0
      t.integer :children_count, null: false, default: 0
    end

    reversible do |dir|
      dir.up do
        load 'tasks/data_migration.rake'

        begin
          Rake::Task['better_together:migrate_data:nested_set_for_navigation_items'].invoke
        rescue RuntimeError
          Rake::Task['app:better_together:migrate_data:nested_set_for_navigation_items'].invoke
        end
      end
    end
  end
end
