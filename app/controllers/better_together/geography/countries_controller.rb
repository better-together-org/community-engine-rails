# frozen_string_literal: true

module BetterTogether
  class Geography::CountriesController < ApplicationController
    before_action :set_geography_country, only: %i[show edit update destroy]
    before_action :authorize_geography_country, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    # GET /geography/countries
    def index
      authorize ::BetterTogether::Geography::Country
      @countries = policy_scope(
        ::BetterTogether::Geography::Country
          .includes(:continents)
          .order(:identifier)
          .with_translations
      )
    end

    # GET /geography/countries/1
    def show; end

    # GET /geography/countries/new
    def new
      @geography_country = ::BetterTogether::Geography::Country.new
      authorize_geography_country
    end

    # GET /geography/countries/1/edit
    def edit; end

    # POST /geography/countries
    def create
      @geography_country = ::BetterTogether::Geography::Country.new(geography_country_params)
      authorize_geography_country

      if @geography_country.save
        redirect_to @geography_country, notice: "Country was successfully created.", status: :see_other
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /geography/countries/1
    def update
      if @geography_country.update(geography_country_params)
        redirect_to @geography_country, notice: "Country was successfully updated.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /geography/countries/1
    def destroy
      @geography_country.destroy
      redirect_to geography_countries_url, notice: "Country was successfully destroyed.", status: :see_other
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_geography_country
      @geography_country = Geography::Country.friendly.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def geography_country_params
      params.require(:geography_country).permit(:identifier, :name, :description, :iso_code, :slug, :protected)
    end

    # Adds a policy check for the country
    def authorize_geography_country
      authorize @geography_country
    end
  end
end
