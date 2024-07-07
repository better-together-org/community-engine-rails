# frozen_string_literal: true

module BetterTogether
  module Geography
    class SettlementsController < ApplicationController # rubocop:todo Style/Documentation
      before_action :set_geography_settlement, only: %i[show edit update destroy]

      # GET /geography/settlements
      def index
        @geography_settlements = Geography::Settlement.all
      end

      # GET /geography/settlements/1
      def show; end

      # GET /geography/settlements/new
      def new
        @geography_settlement = Geography::Settlement.new
      end

      # GET /geography/settlements/1/edit
      def edit; end

      # POST /geography/settlements
      def create
        @geography_settlement = Geography::Settlement.new(geography_settlement_params)

        if @geography_settlement.save
          redirect_to @geography_settlement, notice: 'Settlement was successfully created.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /geography/settlements/1
      def update
        if @geography_settlement.update(geography_settlement_params)
          redirect_to @geography_settlement, notice: 'Settlement was successfully updated.', status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /geography/settlements/1
      def destroy
        @geography_settlement.destroy
        redirect_to geography_settlements_url, notice: 'Settlement was successfully destroyed.', status: :see_other
      end

      private

      # Use callbacks to share common setup or constraints between actions.
      def set_geography_settlement
        @geography_settlement = Geography::Settlement.find(params[:id])
      end

      # Only allow a list of trusted parameters through.
      def geography_settlement_params
        params.fetch(:geography_settlement, {})
      end
    end
  end
end
