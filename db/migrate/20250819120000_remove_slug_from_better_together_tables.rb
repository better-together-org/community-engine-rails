class RemoveSlugFromBetterTogetherTables < ActiveRecord::Migration[7.1]
  TABLES = {
    better_together_communities: "index_better_together_communities_on_slug",
    better_together_geography_continents: "index_better_together_geography_continents_on_slug",
    better_together_geography_countries: "index_better_together_geography_countries_on_slug",
    better_together_geography_regions: "index_better_together_geography_regions_on_slug",
    better_together_geography_settlements: "index_better_together_geography_settlements_on_slug",
    better_together_geography_states: "index_better_together_geography_states_on_slug",
    better_together_navigation_areas: "index_better_together_navigation_areas_on_slug",
    better_together_navigation_items: "index_better_together_navigation_items_on_slug",
    better_together_pages: "index_better_together_pages_on_slug",
    better_together_people: "index_better_together_people_on_slug",
    better_together_platforms: "index_better_together_platforms_on_slug",
    better_together_posts: "index_better_together_posts_on_slug",
    better_together_resource_permissions: "index_better_together_resource_permissions_on_slug",
    better_together_roles: "index_better_together_roles_on_slug",
    better_together_wizard_step_definitions: "index_better_together_wizard_step_definitions_on_slug",
    better_together_wizards: "index_better_together_wizards_on_slug"
  }

  def up
    TABLES.each do |table, index_name|
      if index_exists?(table, :slug, name: index_name)
        remove_index table, name: index_name
      elsif index_exists?(table, :slug)
        remove_index table, :slug
      end

      remove_column table, :slug if column_exists?(table, :slug)
    end
  end

  def down
    TABLES.each do |table, index_name|
      add_column table, :slug, :string unless column_exists?(table, :slug)

      if column_exists?(table, :slug) && !index_exists?(table, :slug, name: index_name)
        add_index table, :slug, unique: true, name: index_name
      end
    end
  end
end
