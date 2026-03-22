# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for NavigationItem
      class NavigationItemResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::NavigationItem'

        translatable_attribute :title

        attributes :slug, :url, :icon, :position, :visible, :item_type, :privacy

        has_one :navigation_area, class_name: 'NavigationArea'
        has_one :parent, class_name: 'NavigationItem'
        has_many :children, class_name: 'NavigationItem'

        filter :visible
        filter :item_type
        filter :navigation_area_id

        def self.creatable_fields(_context)
          %i[title url icon position visible item_type privacy navigation_area parent]
        end

        def self.updatable_fields(_context)
          %i[title url icon position visible item_type privacy parent]
        end
      end
    end
  end
end
