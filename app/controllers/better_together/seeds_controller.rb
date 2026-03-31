# frozen_string_literal: true

module BetterTogether
  # CRUD for Seed records
  class SeedsController < ApplicationController
    before_action :set_seed, only: %i[show edit update destroy]

    # GET /host/seeds
    def index
      authorize Seed
      @seeds = policy_scope(Seed).page(params[:page]).per(25)
    end

    # GET /host/seeds/1
    def show
      authorize @seed
    end

    # GET /host/seeds/new
    def new
      @seed = Seed.new(type: Seed.name, version: '1.0', seeded_at: Time.current)
      authorize @seed
    end

    # GET /host/seeds/1/edit
    def edit
      authorize @seed
    end

    # POST /host/seeds
    def create
      @seed = Seed.new(seed_params)
      authorize @seed
      apply_json_parse_errors

      if @seed.errors.none? && @seed.save
        redirect_to seeds_path, notice: t('flash.generic.created', resource: t('resources.seed'))
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /host/seeds/1
    def update
      authorize @seed
      update_params = seed_params
      apply_json_parse_errors

      if @seed.errors.none? && @seed.update(update_params)
        redirect_to seeds_path, notice: t('flash.generic.updated', resource: t('resources.seed')),
                                status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /host/seeds/1
    def destroy
      authorize @seed
      @seed.destroy!
      redirect_to seeds_url, notice: t('flash.generic.destroyed', resource: t('resources.seed')),
                             status: :see_other
    end

    private

    def set_seed
      @seed = Seed.find(params[:id])
    end

    def seed_params
      permitted = params.require(:seed).permit(
        :identifier, :type, :version, :created_by, :seeded_at, :description,
        :privacy, :seedable_type, :seedable_id
      )
      permitted[:origin] = parse_json_param(:origin)
      permitted[:payload] = parse_json_param(:payload)
      permitted.compact
    end

    def parse_json_param(key)
      raw = params.dig(:seed, key)
      return nil if raw.blank?

      JSON.parse(raw)
    rescue JSON::ParserError
      @json_parse_errors ||= {}
      @json_parse_errors[key] = :invalid_json
      nil
    end

    # Surface any JSON parse failures as model errors so the form re-renders
    # with a validation message instead of silently dropping the submitted value.
    def apply_json_parse_errors
      @json_parse_errors&.each_key do |col|
        @seed.errors.add(col, :invalid, message: t('seeds.errors.invalid_json'))
      end
    end
  end
end
