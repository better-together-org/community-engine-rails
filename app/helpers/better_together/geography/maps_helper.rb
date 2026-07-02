# frozen_string_literal: true

module BetterTogether
  module Geography
    # Helps with map rendering
    module MapsHelper
      def communities_map
        @communities_map ||= begin
          map = CommunityCollectionMap.find_or_create_by(identifier: 'communities')
          map.loaded_collection = @communities if @communities
          map
        end
      end
    end
  end
end
