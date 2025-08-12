# frozen_string_literal: true

module BetterTogether
  module Joatu
    class AgreementsController < ResourceController
      def create
        agreement = BetterTogether::Joatu::Agreement.new(agreement_params)
        if agreement.save
          render json: agreement, status: :created
        else
          render json: { errors: agreement.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def reject
        agreement = BetterTogether::Joatu::Agreement.find(params[:id])
        agreement.reject!
        render json: agreement, status: :ok
      end

      private

      def agreement_params
        params.require(:agreement).permit(:offer_id, :request_id, :terms, :value)
      end

      def resource_class
        BetterTogether::Joatu::Agreement
      end

      def permitted_attributes
        super + %i[offer_id request_id terms value status]
      end
    end
  end
end
