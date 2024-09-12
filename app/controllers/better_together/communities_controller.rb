# frozen_string_literal: true

module BetterTogether
  class CommunitiesController < FriendlyResourceController # rubocop:todo Style/Documentation
    before_action :set_model_instance, only: %i[show edit update destroy]
    before_action :authorize_community, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    helper_method :resource_class

    # GET /communities
    def index
      authorize resource_class
      @communities = policy_scope(resource_collection)
    end

    # GET /communities/1
    def show; end

    # GET /communities/new
    def new
      @community = resource_class.new
      authorize_community
    end

    # GET /communities/1/edit
    def edit; end

    # POST /communities
    def create
      @community = resource_class.new(community_params)
      authorize_community

      if @community.save
        redirect_to @community, notice: 'Community was successfully created.', status: :see_other
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /communities/1
    def update
      if @community.update(community_params)
        redirect_to @community, only_path: true, notice: 'Community was successfully updated.', status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /communities/1
    def destroy
      @community.destroy
      redirect_to communities_url, notice: 'Community was successfully destroyed.', status: :see_other
    end

    private

    def set_model_instance
      @community = set_resource_instance
    end

    def community_params
      permitted_attributes = %i[
        name description slug privacy
      ]
      params.require(:community).permit(permitted_attributes)
    end

    # Adds a policy check for the community
    def authorize_community
      authorize @community
    end

    def resource_class
      ::BetterTogether::Community
    end

    def resource_collection
      resource_class.with_translations
    end
  end
end
