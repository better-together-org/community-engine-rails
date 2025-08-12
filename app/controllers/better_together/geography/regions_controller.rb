# frozen_string_literal: true

module BetterTogether
  module Geography
    class RegionsController < FriendlyResourceController # rubocop:todo Style/Documentation
      before_action :set_geography_region, only: %i[show edit update destroy]
      before_action :authorize_geography_region, only: %i[show edit update destroy]
      after_action :verify_authorized, except: :index

      # GET /geography/regions
      def index
        authorize resource_class
        @geography_regions = policy_scope(
          resource_collection
        )
      end

      # GET /geography/regions/1
      def show; end

      # GET /geography/regions/new
      def new
        @geography_region = resource_class.new
        authorize_geography_region
      end

      # GET /geography/regions/1/edit
      def edit; end

      # POST /geography/regions
      def create
        @geography_region = resource_class.new(geography_region_params)
        authorize_geography_region

        if @geography_region.save
          redirect_to @geography_region, notice: 'Region was successfully created.'
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @geography_region }
              )
            end
            format.html { render :new, status: :unprocessable_entity }
          end
        end
      end

      # PATCH/PUT /geography/regions/1
      def update
        if @geography_region.update(geography_region_params)
          redirect_to @geography_region, notice: 'Region was successfully updated.', status: :see_other
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @geography_region }
              )
            end
            format.html { render :edit, status: :unprocessable_entity }
          end
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
        @geography_region = set_resource_instance
      end

      # Adds a policy check for the region
      def authorize_geography_region
        authorize @geography_region
      end

      def resource_class
        ::BetterTogether::Geography::Region
      end

      def resource_collection
        resource_class
          .includes(:country, :settlements, :state)
          .order(:identifier)
          .with_translations
      end

      # Only allow a list of trusted parameters through.
      def geography_region_params
        params.fetch(:geography_region, {})
      end
    end
  end
end
