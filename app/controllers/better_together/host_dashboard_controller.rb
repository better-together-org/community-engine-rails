# frozen_string_literal: true

module BetterTogether
  # Displays recent resources and counts on the host dashboard
  class HostDashboardController < ApplicationController
    ROOT_RESOURCE_DEFINITIONS = [
      [Community, :community_path],
      [NavigationArea, :navigation_area_path],
      [Page, :page_path],
      [Platform, :platform_path],
      [Person, :person_path],
      [Role, :role_path],
      [ResourcePermission, :resource_permission_path],
      [User, :user_path],
      [Conversation, :conversation_path],
      [Message, :message_path],
      [Category, :category_path]
    ].freeze

    CONTENT_RESOURCE_DEFINITIONS = [
      [Content::Block, :content_block_path]
    ].freeze

    GEOGRAPHY_RESOURCE_DEFINITIONS = [
      [Geography::Continent, :geography_continent_path],
      [Geography::Country, :geography_country_path],
      [Geography::State, :geography_state_path],
      [Geography::Region, :geography_region_path],
      [Geography::Settlement, :geography_settlement_path]
    ].freeze

    def index
      @root_resources = build_resources(ROOT_RESOURCE_DEFINITIONS)
      @content_resources = build_resources(CONTENT_RESOURCE_DEFINITIONS)
      @geography_resources = build_resources(GEOGRAPHY_RESOURCE_DEFINITIONS)
    end

    private

    def build_resources(definitions)
      definitions.map do |klass, helper|
        {
          collection: klass.order(created_at: :desc).limit(3),
          count: klass.count,
          url_helper: helper
        }
      end
    end
  end
end
