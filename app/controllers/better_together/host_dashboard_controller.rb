module BetterTogether
  class HostDashboardController < ApplicationController
    def index
      @communities = Community.order(created_at: :desc).limit(3)
      @navigation_areas = NavigationArea.order(created_at: :desc).limit(3)
      @pages = Page.order(created_at: :desc).limit(3)
      @platforms = Platform.order(created_at: :desc).limit(3)
      @people = Person.order(created_at: :desc).limit(3)
      @roles = Role.order(created_at: :desc).limit(3)
      @resource_permissions = ResourcePermission.order(created_at: :desc).limit(3)
  
      @community_count = Community.count
      @navigation_area_count = NavigationArea.count
      @page_count = Page.count
      @platform_count = Platform.count
      @person_count = Person.count
      @role_count = Role.count
      @resource_permission_count = ResourcePermission.count
    end
  end
end
