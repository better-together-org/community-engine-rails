# frozen_string_literal: true

# Allows for dynamic dispatch of url helpers instead of hard-coded urls
class AddRouteNameToBetterTogetherNavigationItems < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_navigation_items, :route_name, :string
  end
end
