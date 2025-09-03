# frozen_string_literal: true

module BetterTogether
  # CRUD for Seed records
  class SeedsController < ApplicationController
    before_action :set_seed, only: %i[show edit update destroy]

    # GET /seeds
    def index
      @seeds = Seed.all
    end

    # GET /seeds/1
    def show; end

    # GET /seeds/new
    def new
      @seed = Seed.new
    end

    # GET /seeds/1/edit
    def edit; end

    # POST /seeds
    def create
      @seed = Seed.new(seed_params)

      if @seed.save
        redirect_to @seed, notice: 'Seed was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /seeds/1
    def update
      if @seed.update(seed_params)
        redirect_to @seed, notice: 'Seed was successfully updated.', status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /seeds/1
    def destroy
      @seed.destroy!
      redirect_to seeds_url, notice: 'Seed was successfully destroyed.', status: :see_other
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_seed
      @seed = Seed.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def seed_params
      params.fetch(:seed, {})
    end
  end
end
