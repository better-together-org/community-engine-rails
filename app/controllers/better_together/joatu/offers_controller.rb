# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Allows platform managers to create offers for invitations
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
    end
  end
end
