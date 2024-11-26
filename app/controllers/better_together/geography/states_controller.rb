# frozen_string_literal: true

module BetterTogether
  module Geography
    class StatesController < ApplicationController
      before_action :set_geography_state, only: %i[show edit update destroy]
      before_action :authorize_geography_state, only: %i[show edit update destroy]
      after_action :verify_authorized, except: :index

      # GET /geography/states
      def index
        authorize ::BetterTogether::Geography::State
        @geography_states = policy_scope(::BetterTogether::Geography::State.with_translations)
      end

      # GET /geography/states/1
      def show; end

      # GET /geography/states/new
      def new
        @geography_state = ::BetterTogether::Geography::State.new
        authorize_geography_state
      end

      # GET /geography/states/1/edit
      def edit; end

      # POST /geography/states
      def create
        @geography_state = ::BetterTogether::Geography::State.new(geography_state_params)
        authorize_geography_state

        if @geography_state.save
          redirect_to @geography_state, notice: 'State was successfully created.', status: :see_other
        else
          render :new, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /geography/states/1
      def update
        if @geography_state.update(geography_state_params)
          redirect_to @geography_state, notice: 'State was successfully updated.', status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /geography/states/1
      def destroy
        @geography_state.destroy
        redirect_to geography_states_url, notice: 'State was successfully destroyed.', status: :see_other
      end

      private

      # Use callbacks to share common setup or constraints between actions.
      def set_geography_state
        @geography_state = Geography::State.friendly.find(params[:id])
      end

      # Only allow a list of trusted parameters through.
      def geography_state_params
        params.require(:geography_state).permit(:identifier, :name, :description, :iso_code, :slug, :protected,
                                                :country_id)
      end

      # Adds a policy check for the state
      def authorize_geography_state
        authorize @geography_state
      end
    end
  end
end
