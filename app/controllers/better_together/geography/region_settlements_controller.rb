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
      def create
        @geography_region_settlement = Geography::RegionSettlement.new(geography_region_settlement_params)

        if @geography_region_settlement.save
          redirect_to @geography_region_settlement, notice: 'Region settlement was successfully created.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /geography/region_settlements/1
      def update
        if @geography_region_settlement.update(geography_region_settlement_params)
          redirect_to @geography_region_settlement, notice: 'Region settlement was successfully updated.',
                                                    status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /geography/region_settlements/1
      def destroy
        @geography_region_settlement.destroy
        redirect_to geography_region_settlements_url, notice: 'Region settlement was successfully destroyed.',
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
