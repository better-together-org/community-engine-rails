
class AddSidebarNavToBetterTogetherPages < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_pages do |t|
      t.bt_references :sidebar_nav, target_table: :better_together_navigation_areas, index: {
        name: 'by_page_sidebar_nav'
      }
    end
  end
end