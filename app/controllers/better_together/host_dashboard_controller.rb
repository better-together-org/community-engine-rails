# frozen_string_literal: true

module BetterTogether
  class HostDashboardController < ApplicationController # rubocop:todo Style/Documentation
    ROOT_RESOURCE_DEFINITIONS = [
      { model: Community, url_helper: :community_path },
      { model: NavigationArea, url_helper: :navigation_area_path },
      { model: Page, url_helper: :page_path },
      { model: Platform, url_helper: :platform_path },
      { model: Person, url_helper: :person_path },
      { model: Role, url_helper: :role_path },
      { model: ResourcePermission, url_helper: :resource_permission_path },
      { model: User, url_helper: :user_path },
      { model: Conversation, url_helper: :conversation_path },
      { model: Message, url_helper: :message_path },
      { model: Category, url_helper: :category_path }
    ]

    CONTENT_RESOURCE_DEFINITIONS = [
      { model: Content::Block, url_helper: :content_block_path }
    ]

    GEOGRAPHY_RESOURCE_DEFINITIONS = [
      { model: Geography::Continent, url_helper: :geography_continent_path },
      { model: Geography::Country, url_helper: :geography_country_path },
      { model: Geography::State, url_helper: :geography_state_path },
      { model: Geography::Region, url_helper: :geography_region_path },
      { model: Geography::Settlement, url_helper: :geography_settlement_path }
    ]

    def index
      @root_resources = build_resources(ROOT_RESOURCE_DEFINITIONS)
      @content_resources = build_resources(CONTENT_RESOURCE_DEFINITIONS)
      @geography_resources = build_resources(GEOGRAPHY_RESOURCE_DEFINITIONS)
    end

    protected

    def build_resources(definitions)
      definitions.map do |definition|
        model = evaluate(definition[:model])
        url_helper = evaluate(definition[:url_helper])

        collection = if definition[:collection]&.respond_to?(:call)
                       definition[:collection].call
                     else
                       model.order(created_at: :desc).limit(3)
                     end

        count = if definition[:count]&.respond_to?(:call)
                  definition[:count].call
                else
                  model.count
                end

        {
          model_class: model,
          collection: collection,
          count: count,
          url_helper: url_helper
        }
      end
    end

    private

    def evaluate(value)
      value.respond_to?(:call) ? value.call : value
    end
  end
end

