# frozen_string_literal: true

# This constraint is no longer needed as name is now translatable with Mobility
class RemoveColumnNullConstraintFromBetterTogetherNavigationAreasName < ActiveRecord::Migration[7.1]
  def up
    change_column_null :better_together_navigation_areas, :name, true
  end

  def down
    change_column_null :better_together_navigation_areas, :name, false
  end
end
