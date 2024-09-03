class RemoveColumnNullConstraintFromBetterTogetherNavigationAreasName < ActiveRecord::Migration[7.1]
  def up
    change_column_null :better_together_navigation_areas, :name, true
  end

  def down
    change_column_null :better_together_navigation_areas, :name, false
  end
end
