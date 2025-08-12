# frozen_string_literal: true

module BetterTogether
  module Geography
    class CountriesController < FriendlyResourceController # rubocop:todo Style/Documentation
      before_action :set_geography_country, only: %i[show edit update destroy]
      before_action :authorize_geography_country, only: %i[show edit update destroy]
      after_action :verify_authorized, except: :index

      # GET /geography/countries
      def index
        authorize resource_class
        @countries = policy_scope(
          resource_collection
        )
      end

      # GET /geography/countries/1
      def show; end

      # GET /geography/countries/new
      def new
        @geography_country = resource_class.new
        authorize_geography_country
      end

      # GET /geography/countries/1/edit
      def edit; end

      # POST /geography/countries
      def create # rubocop:todo Metrics/MethodLength
        @geography_country = resource_class.new(geography_country_params)
        authorize_geography_country

        if @geography_country.save
          redirect_to @geography_country, notice: 'Country was successfully created.', status: :see_other
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @geography_country }
              )
            end
            format.html { render :new, status: :unprocessable_entity }
          end
        end
      end

      # PATCH/PUT /geography/countries/1
      def update # rubocop:todo Metrics/MethodLength
        if @geography_country.update(geography_country_params)
          redirect_to @geography_country, notice: 'Country was successfully updated.', status: :see_other
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @geography_country }
              )
            end
            format.html { render :edit, status: :unprocessable_entity }
          end
        end
      end

      # DELETE /geography/countries/1
      def destroy
        @geography_country.destroy
        redirect_to geography_countries_url, notice: 'Country was successfully destroyed.', status: :see_other
      end

      private

      # Use callbacks to share common setup or constraints between actions.
      def set_geography_country
        @geography_country = set_resource_instance
      end

      # Only allow a list of trusted parameters through.
      def geography_country_params
        params.require(:geography_country).permit(:identifier, :name, :description, :iso_code, :slug, :protected)
      end

      # Adds a policy check for the country
      def authorize_geography_country
        authorize @geography_country
      end

      def resource_class
        ::BetterTogether::Geography::Country
      end

      def resource_collection
        resource_class
          .includes(:continents)
          .order(:identifier)
          .with_translations
      end
    end
  end
end
