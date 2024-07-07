# frozen_string_literal: true

module BetterTogether
  module Geography
    class RegionsController < ApplicationController # rubocop:todo Style/Documentation
      before_action :set_geography_region, only: %i[show edit update destroy]

      # GET /geography/regions
      def index
        @geography_regions = Geography::Region.all
      end

      # GET /geography/regions/1
      def show; end

      # GET /geography/regions/new
      def new
        @geography_region = Geography::Region.new
      end

      # GET /geography/regions/1/edit
      def edit; end

      # POST /geography/regions
      def create
        @geography_region = Geography::Region.new(geography_region_params)

        if @geography_region.save
          redirect_to @geography_region, notice: 'Region was successfully created.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /geography/regions/1
      def update
        if @geography_region.update(geography_region_params)
          redirect_to @geography_region, notice: 'Region was successfully updated.', status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /geography/regions/1
      def destroy
        @geography_region.destroy
        redirect_to geography_regions_url, notice: 'Region was successfully destroyed.', status: :see_other
      end

      private

      # Use callbacks to share common setup or constraints between actions.
      def set_geography_region
        @geography_region = Geography::Region.find(params[:id])
      end

      # Only allow a list of trusted parameters through.
      def geography_region_params
        params.fetch(:geography_region, {})
      end
    end
  end
end
