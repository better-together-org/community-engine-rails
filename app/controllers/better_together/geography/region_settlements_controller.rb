# frozen_string_literal: true

module BetterTogether
  module Geography
    class RegionSettlementsController < ApplicationController # rubocop:todo Style/Documentation
      before_action :set_geography_region_settlement, only: %i[show edit update destroy]

      # GET /geography/region_settlements
      def index
        @geography_region_settlements = Geography::RegionSettlement.all
      end

      # GET /geography/region_settlements/1
      def show; end

      # GET /geography/region_settlements/new
      def new
        @geography_region_settlement = Geography::RegionSettlement.new
      end

      # GET /geography/region_settlements/1/edit
      def edit; end

      # POST /geography/region_settlements
      def create # rubocop:todo Metrics/MethodLength
        @geography_region_settlement = Geography::RegionSettlement.new(geography_region_settlement_params)

        if @geography_region_settlement.save
          redirect_to @geography_region_settlement,
                      notice: t('flash.generic.created', resource: t('resources.region_settlement'))
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @geography_region_settlement }
              )
            end
            format.html { render :new, status: :unprocessable_content }
          end
        end
      end

      # PATCH/PUT /geography/region_settlements/1
      def update # rubocop:todo Metrics/MethodLength
        if @geography_region_settlement.update(geography_region_settlement_params)
          redirect_to @geography_region_settlement,
                      notice: t('flash.generic.updated', resource: t('resources.region_settlement')),
                      status: :see_other
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @geography_region_settlement }
              )
            end
            format.html { render :edit, status: :unprocessable_content }
          end
        end
      end

      # DELETE /geography/region_settlements/1
      def destroy
        @geography_region_settlement.destroy
        redirect_to geography_region_settlements_url,
                    notice: t('flash.generic.destroyed', resource: t('resources.region_settlement')),
                    status: :see_other
      end

      private

      # Use callbacks to share common setup or constraints between actions.
      def set_geography_region_settlement
        @geography_region_settlement = Geography::RegionSettlement.find(params[:id])
      end

      # Only allow a list of trusted parameters through.
      def geography_region_settlement_params
        params.fetch(:geography_region_settlement, {})
      end
    end
  end
end
