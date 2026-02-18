# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for NavigationArea
      class NavigationAreaResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::NavigationArea'

        translatable_attribute :name

        attributes :slug, :style, :visible

        has_many :navigation_items, class_name: 'NavigationItem'

        filter :visible

        def self.creatable_fields(_context)
          %i[name style visible]
        end

        def self.updatable_fields(_context)
          %i[name style visible]
        end
      end
    end
  end
end
