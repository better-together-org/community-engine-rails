# frozen_string_literal: true

module BetterTogether
  module Geography
    # Helps with map rendering
    module MapsHelper
      def communities_map
        @communities_map ||= CommunityCollectionMap.find_or_create_by(identifier: 'communities')
      end
    end
  end
end
