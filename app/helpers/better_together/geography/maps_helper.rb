# frozen_string_literal: true

module BetterTogether
  module Geography
    # Helps with map rendering
    module MapsHelper
      def communities_map
        @communities_map ||= begin
          map = CommunityCollectionMap.find_or_create_by(identifier: 'communities')
          map.loaded_collection = @communities if @communities
          map.visible_scope = policy_scope(::BetterTogether::Community)
          map
        end
      end

      def events_map
        @events_map ||= EventCollectionMap.find_or_create_by(identifier: 'events').tap do |map|
          map.visible_scope = policy_scope(::BetterTogether::Event)
        end
      end
    end
  end
end
