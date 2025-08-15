# frozen_string_literal: true

module BetterTogether
  module Joatu
    # AgreementsController manages offer-request agreements
    class AgreementsController < ApplicationController
      before_action :set_agreement, only: %i[show accept reject update destroy]

      # POST /joatu/requests/:request_id/agreements
      def create
        request = BetterTogether::Joatu::Request.find(params[:request_id])
        offer = BetterTogether::Joatu::Offer.find(params[:offer_id])
        @agreement = BetterTogether::Joatu::Agreement.create!(
          request:,
          offer:,
          terms: params[:terms],
          value: params[:value]
        )
        redirect_to joatu_agreement_path(@agreement)
      end

      # GET /joatu/agreements
      def index
        authorize BetterTogether::Joatu::Agreement
        @agreements = policy_scope(BetterTogether::Joatu::Agreement)
      end

      # GET /joatu/agreements/:id
      def show; end

      # POST /joatu/agreements/:id/accept
      def accept
        authorize @agreement
        @agreement.accept!
        redirect_to joatu_agreement_path(@agreement), notice: 'Agreement accepted'
      end

      # POST /joatu/agreements/:id/reject
      def reject
        authorize @agreement
        @agreement.reject!
        redirect_to joatu_agreement_path(@agreement), notice: 'Agreement rejected'
      end

      # PATCH/PUT /joatu/agreements/:id
      def update
        authorize @agreement
        if @agreement.update(agreement_params)
          redirect_to joatu_agreement_path(@agreement), notice: 'Agreement updated'
        else
          render :show, status: :unprocessable_content
        end
      end

      # DELETE /joatu/agreements/:id
      def destroy
        authorize @agreement
        @agreement.destroy
        redirect_to joatu_agreements_path, notice: 'Agreement removed'
      end

      private

      def set_agreement
        @agreement = BetterTogether::Joatu::Agreement.find(params[:id])
      end

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
