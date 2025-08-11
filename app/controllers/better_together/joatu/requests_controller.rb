# frozen_string_literal: true

module BetterTogether
  module Joatu
    class RequestsController < ActionController::API
      def create
        request_record = BetterTogether::Joatu::Request.new(request_params)
        if request_record.save
          render json: request_record, status: :created
        else
          render json: { errors: request_record.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def request_params
        params.require(:request).permit(:name, :description, :creator_id, category_ids: [])
      end
    end
  end
end
