# frozen_string_literal: true

module BetterTogether
  class PlatformsController < ApplicationController # rubocop:todo Style/Documentation
    before_action :set_platform, only: %i[show edit update destroy]
    before_action :authorize_platform, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    # GET /platforms
    def index
      # @platforms = ::BetterTogether::Platform.all
      # authorize @platforms
      authorize ::BetterTogether::Platform
      @platforms = policy_scope(::BetterTogether::Platform.with_translations)
    end

    # GET /platforms/1
    def show; end

    # GET /platforms/new
    def new
      @platform = ::BetterTogether::Platform.new
      authorize_platform
    end

    # GET /platforms/1/edit
    def edit; end

    # POST /platforms
    def create
      @platform = ::BetterTogether::Platform.new(platform_params)
      authorize_platform

      if @platform.save
        redirect_to @platform, notice: 'Platform was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /platforms/1
    def update
      if @platform.update(platform_params)
        redirect_to @platform, notice: 'Platform was successfully updated.', status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /platforms/1
    def destroy
      @platform.destroy
      redirect_to platforms_url, notice: 'Platform was successfully destroyed.', status: :see_other
    end

    private

    def set_platform
      @platform = ::BetterTogether::Platform.includes(
        person_platform_memberships: %i[member role]
      ).friendly.find(params[:id])
    end

    def platform_params
      permitted_attributes = %i[
        name description slug url time_zone privacy
      ]
      params.require(:platform).permit(permitted_attributes)
    end

    # Adds a policy check for the platform
    def authorize_platform
      authorize @platform
    end
  end
end
