module BetterTogether
  class PlatformsController < ApplicationController
    before_action :set_platform, only: %i[ show edit update destroy ]

    # GET /platforms
    def index
      @platforms = Platform.all
    end

    # GET /platforms/1
    def show
    end

    # GET /platforms/new
    def new
      @platform = Platform.new
    end

    # GET /platforms/1/edit
    def edit
    end

    # POST /platforms
    def create
      @platform = Platform.new(platform_params)

      if @platform.save
        redirect_to @platform, notice: "Platform was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /platforms/1
    def update
      if @platform.update(platform_params)
        redirect_to @platform, notice: "Platform was successfully updated.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /platforms/1
    def destroy
      @platform.destroy
      redirect_to platforms_url, notice: "Platform was successfully destroyed.", status: :see_other
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_platform
        @platform = ::BetterTogether::Platform.includes(
          platform_person_memberships: %i[member role]
        ).friendly.find(params[:id])
      end

      # Only allow a list of trusted parameters through.
      def platform_params
        params.fetch(:platform, {})
      end
  end
end
