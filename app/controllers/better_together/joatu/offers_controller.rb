# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Offer
    class OffersController < FriendlyResourceController
      protected

      def resource_class
        ::BetterTogether::Joatu::Offer
      end

      def param_name
        :"joatu_#{super}"
      end

      def resource_params
        super.tap do |attrs|
          attrs[:creator_id] ||= helpers.current_person&.id
        end
      end
    end
  end
end
