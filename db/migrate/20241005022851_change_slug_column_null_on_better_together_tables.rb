class ChangeSlugColumnNullOnBetterTogetherTables < ActiveRecord::Migration[7.1]
  def change
    change_column_null :better_together_communities, :slug, true
    change_column_null :better_together_people, :slug, true
    change_column_null :better_together_pages, :slug, true
    change_column_null :better_together_platforms, :slug, true
    change_column_null :better_together_resource_permissions, :slug, true
    change_column_null :better_together_roles, :slug, true
    change_column_null :better_together_navigation_areas, :slug, true
    change_column_null :better_together_navigation_items, :slug, true
    change_column_null :better_together_wizards, :slug, true
    change_column_null :better_together_wizard_step_definitions, :slug, true

    change_column_null :better_together_geography_continents, :slug, true
    change_column_null :better_together_geography_countries, :slug, true
    change_column_null :better_together_geography_states, :slug, true
    change_column_null :better_together_geography_regions, :slug, true
    change_column_null :better_together_geography_settlements, :slug, true
  end
end
