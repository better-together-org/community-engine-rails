# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for Joatu offers
    class OffersController < ResourceController
      private

      def resource_class
        BetterTogether::Joatu::Offer
      end

      def permitted_attributes
        super + %i[status name description]
      end
    end
  end
end
