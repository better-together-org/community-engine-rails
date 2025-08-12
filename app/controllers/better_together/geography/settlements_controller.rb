# frozen_string_literal: true

module BetterTogether
  module Geography
    class SettlementsController < FriendlyResourceController # rubocop:todo Style/Documentation
      before_action :set_geography_settlement, only: %i[show edit update destroy]
      before_action :authorize_geography_settlement, only: %i[show edit update destroy]
      after_action :verify_authorized, except: :index

      # GET /geography/settlements
      def index
        authorize resource_class
        @geography_settlements = policy_scope(
          resource_collection
        )
      end

      # GET /geography/settlements/1
      def show; end

      # GET /geography/settlements/new
      def new
        @geography_settlement = resource_class.new
        authorize_geography_settlement
      end

      # GET /geography/settlements/1/edit
      def edit; end

      # POST /geography/settlements
      def create
        @geography_settlement = resource_class.new(geography_settlement_params)
        authorize_geography_settlement

        if @geography_settlement.save
          redirect_to @geography_settlement, notice: 'Settlement was successfully created.'
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @geography_settlement }
              )
            end
            format.html { render :new, status: :unprocessable_entity }
          end
        end
      end

      # PATCH/PUT /geography/settlements/1
      def update
        if @geography_settlement.update(geography_settlement_params)
          redirect_to @geography_settlement, notice: 'Settlement was successfully updated.', status: :see_other
        else
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @geography_settlement }
              )
            end
            format.html { render :edit, status: :unprocessable_entity }
          end
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
        @geography_settlement = set_resource_instance
      end

      # Adds a policy check for the settlement
      def authorize_geography_settlement
        authorize @geography_settlement
      end

      def resource_class
        ::BetterTogether::Geography::Settlement
      end

      def resource_collection
        resource_class
          .includes(:country, :regions, :state)
          .order(:identifier)
          .with_translations
      end

      # Only allow a list of trusted parameters through.
      def geography_settlement_params
        params.fetch(:geography_settlement, {})
      end
    end
  end
end
