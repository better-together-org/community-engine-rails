# frozen_string_literal: true

module BetterTogether
  module Geography
    # CRUD for Maps
    class MapsController < FriendlyResourceController
      protected

      def resource_class
        ::BetterTogether::Geography::Map
      end

      def resource_name(plural: false)
        name = 'geography_map'
        name = name.pluralize if plural

        name.underscore
      end
    end
  end
end
