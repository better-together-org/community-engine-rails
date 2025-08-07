# frozen_string_literal: true

module BetterTogether
  module Geography
    # Custom Map subtype for Communities
    class CommunityMap < ::BetterTogether::Geography::Map
      def self.mappable_class
        ::BetterTogether::Community
      end
    end
  end
end
