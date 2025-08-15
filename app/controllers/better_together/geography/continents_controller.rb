# frozen_string_literal: true

module BetterTogether
  module Geography
    class ContinentsController < ApplicationController # rubocop:todo Style/Documentation
      before_action :set_geography_continent, only: %i[show edit update destroy]

      # GET /geography/continents
      def index
        @geography_continents = Geography::Continent.all
      end

      # GET /geography/continents/1
      def show; end

      # GET /geography/continents/new
      def new
        @geography_continent = Geography::Continent.new
      end

      # GET /geography/continents/1/edit
      def edit; end

      # POST /geography/continents
      def create # rubocop:todo Metrics/MethodLength
        @geography_continent = Geography::Continent.new(geography_continent_params)

        if @geography_continent.save
          redirect_to @geography_continent, notice: 'Continent was successfully created.'
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @geography_continent }
              )
            end
            format.html { render :new, status: :unprocessable_content }
          end
        end
      end

      # PATCH/PUT /geography/continents/1
      def update # rubocop:todo Metrics/MethodLength
        if @geography_continent.update(geography_continent_params)
          redirect_to @geography_continent, notice: 'Continent was successfully updated.', status: :see_other
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @geography_continent }
              )
            end
            format.html { render :edit, status: :unprocessable_content }
          end
        end
      end

      # DELETE /geography/continents/1
      def destroy
        @geography_continent.destroy
        redirect_to geography_continents_url, notice: 'Continent was successfully destroyed.', status: :see_other
      end

      private

      # Use callbacks to share common setup or constraints between actions.
      def set_geography_continent
        @geography_continent = Geography::Continent.friendly.find(params[:id])
      end

      # Only allow a list of trusted parameters through.
      def geography_continent_params
        params.fetch(:geography_continent, {})
      end
    end
  end
end
