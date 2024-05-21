module BetterTogether
  class Geography::ContinentsController < ApplicationController
    before_action :set_geography_continent, only: %i[ show edit update destroy ]

    # GET /geography/continents
    def index
      @geography_continents = Geography::Continent.all
    end

    # GET /geography/continents/1
    def show
    end

    # GET /geography/continents/new
    def new
      @geography_continent = Geography::Continent.new
    end

    # GET /geography/continents/1/edit
    def edit
    end

    # POST /geography/continents
    def create
      @geography_continent = Geography::Continent.new(geography_continent_params)

      if @geography_continent.save
        redirect_to @geography_continent, notice: "Continent was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /geography/continents/1
    def update
      if @geography_continent.update(geography_continent_params)
        redirect_to @geography_continent, notice: "Continent was successfully updated.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /geography/continents/1
    def destroy
      @geography_continent.destroy
      redirect_to geography_continents_url, notice: "Continent was successfully destroyed.", status: :see_other
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
