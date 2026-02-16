# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to read navigation structure
    # Returns navigation areas with their items for building menus
    class ManageNavigationTool < ApplicationTool
      description 'List navigation areas and their items for menu structure'

      arguments do
        optional(:area_id)
          .filled(:string)
          .description('Specific navigation area ID to retrieve (returns all if omitted)')
        optional(:visible_only)
          .filled(:bool)
          .description('Only return visible items (default: true)')
      end

      # List navigation structure
      # @param area_id [String] Optional specific area
      # @param visible_only [Boolean] Filter by visibility (default: true)
      # @return [String] JSON array of navigation area objects with items
      def call(area_id: nil, visible_only: true)
        with_timezone_scope do
          areas = fetch_areas(area_id)
          result = JSON.generate(areas.map { |area| serialize_area(area, visible_only) })

          log_invocation('manage_navigation',
                         { area_id: area_id, visible_only: visible_only },
                         result.bytesize)
          result
        end
      end

      private

      def fetch_areas(area_id)
        scope = policy_scope(BetterTogether::NavigationArea)
        scope = scope.where(id: area_id) if area_id.present?
        scope.includes(:navigation_items).order(:name)
      end

      def serialize_area(area, visible_only)
        items = area.navigation_items
        items = items.select(&:visible?) if visible_only

        {
          id: area.id,
          name: area.name,
          style: area.style,
          visible: area.visible?,
          items: items.sort_by(&:position).map { |item| serialize_item(item) }
        }
      end

      def serialize_item(item)
        {
          id: item.id,
          title: item.title,
          url: item.url,
          icon: item.icon,
          position: item.position,
          visible: item.visible?,
          item_type: item.item_type,
          parent_id: item.parent_id,
          children_count: item.children_count
        }
      end
    end
  end
end
