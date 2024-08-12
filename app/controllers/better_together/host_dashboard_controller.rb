# frozen_string_literal: true

module BetterTogether
  class HostDashboardController < ApplicationController # rubocop:todo Style/Documentation
    def index # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      @communities = Community.order(created_at: :desc).limit(3)
      @navigation_areas = NavigationArea.order(created_at: :desc).limit(3)
      @pages = Page.order(created_at: :desc).limit(3)
      @platforms = Platform.order(created_at: :desc).limit(3)
      @people = Person.order(created_at: :desc).limit(3)
      @roles = Role.order(created_at: :desc).limit(3)
      @resource_permissions = ResourcePermission.order(created_at: :desc).limit(3)
      
      @geography_continents = Geography::Continent.order(created_at: :desc).limit(3)
      @geography_countries = Geography::Country.order(created_at: :desc).limit(3)
      @geography_states = Geography::State.order(created_at: :desc).limit(3)
      @geography_regions = Geography::Region.order(created_at: :desc).limit(3)
      @geography_settlements = Geography::Settlement.order(created_at: :desc).limit(3)

      @community_count = Community.count
      @navigation_area_count = NavigationArea.count
      @page_count = Page.count
      @platform_count = Platform.count
      @person_count = Person.count
      @role_count = Role.count
      @resource_permission_count = ResourcePermission.count
      
      @geography_continent_count = Geography::Continent.count
      @geography_country_count = Geography::Country.count
      @geography_state_count = Geography::State.count
      @geography_region_count = Geography::Region.count
      @geography_settlement_count = Geography::Settlement.count
    end
  end
end
