# frozen_string_literal: true

module BetterTogether
  module Joatu
    class OffersController < ActionController::API
      def create
        offer = BetterTogether::Joatu::Offer.new(offer_params)
        if offer.save
          render json: offer, status: :created
        else
          render json: { errors: offer.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def offer_params
        params.require(:offer).permit(:name, :description, :creator_id, category_ids: [])
      end
    end
  end
end
