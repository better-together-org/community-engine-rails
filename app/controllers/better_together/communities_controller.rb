module BetterTogether
  class CommunitiesController < ApplicationController
    before_action :set_community, only: %i[show edit update destroy]
    before_action :authorize_community, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    # GET /communities
    def index
      authorize ::BetterTogether::Community
      @communities = policy_scope(::BetterTogether::Community.with_translations)
    end

    # GET /communities/1
    def show
    end

    # GET /communities/new
    def new
      @community = ::BetterTogether::Community.new
      authorize_community
    end

    # GET /communities/1/edit
    def edit
    end

    # POST /communities
    def create
      @community = ::BetterTogether::Community.new(community_params)
      authorize_community

      if @community.save
        redirect_to @community, notice: "Community was successfully created.", status: :see_other
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /communities/1
    def update
      if @community.update(community_params)
        redirect_to @community, notice: "Community was successfully updated.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /communities/1
    def destroy
      @community.destroy
      redirect_to communities_url, notice: "Community was successfully destroyed.", status: :see_other
    end

    private
      def set_community
        @community = ::BetterTogether::Community.friendly.find(params[:id])
      end

      def community_params
        permitted_attributes = [
          :name, :description, :slug, :privacy
        ]
        params.require(:community).permit(permitted_attributes)
      end

      # Adds a policy check for the community
      def authorize_community
        authorize @community
      end
  end
end
