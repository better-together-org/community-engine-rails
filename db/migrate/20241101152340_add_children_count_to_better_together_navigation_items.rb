class AddChildrenCountToBetterTogetherNavigationItems < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_navigation_items, :children_count, :integer, default: 0, null: false
  end
end
