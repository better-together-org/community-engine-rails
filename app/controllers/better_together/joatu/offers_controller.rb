# frozen_string_literal: true

module BetterTogether
  module Joatu
    # CRUD for BetterTogether::Joatu::Offer
    class OffersController < ResourceController
      protected

      def resource_class
        ::BetterTogether::Joatu::Offer
      end

      def resource_params
        super.tap do |attrs|
          attrs[:creator_id] ||= helpers.current_person&.id
          attrs[:target_type] = 'BetterTogether::PlatformInvitation'
          attrs[:target_id] = params.dig(:offer, :platform_invitation_id)
        end
      end

      def permitted_attributes
        super + %i[status name description]
      end
    end
  end
end
