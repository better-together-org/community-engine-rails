# frozen_string_literal: true

module BetterTogether
  class CommunitiesController < FriendlyResourceController # rubocop:todo Style/Documentation
    before_action :set_model_instance, only: %i[show edit update destroy]
    before_action :authorize_community, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    # GET /communities
    def index
      authorize resource_class
      @communities = policy_scope(resource_collection)
    end

    # GET /communities/1
    def show
      # Dispatch the background job for tracking the page view
      BetterTogether::Metrics::TrackPageViewJob.perform_later(@community, I18n.locale.to_s)
    end

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

      respond_to do |format|
        if @community.save
          flash[:notice] = t('community.created')
          format.html { redirect_to @community, notice: t('community.created') }
          format.turbo_stream do
            redirect_to @community, only_path: true
          end
        else
          flash.now[:alert] = t('community.create_failed')
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update('form_errors', partial: 'layouts/better_together/errors',
                                                 locals: { object: @community }),
              turbo_stream.update('community_form', partial: 'better_together/communities/form',
                                                         locals: { community: @community })
            ]
          end
        end
      end
    end

    # PATCH/PUT /communities/1
    def update
      respond_to do |format|
        if @community.update(community_params)
          flash[:notice] = t('community.updated')
          format.html { redirect_to edit_community_path(@community), notice: t('community.updated') }
          format.turbo_stream do
            redirect_to edit_community_path(@community), only_path: true
          end
        else
          flash.now[:alert] = t('community.update_failed')
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update('form_errors', partial: 'layouts/better_together/errors',
                                                 locals: { object: @community }),
              turbo_stream.update('community_form', partial: 'communities/form',
                                                         locals: { community: @community })
            ]
          end
        end
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
      params.require(resource_class.name.demodulize.underscore.to_sym).permit(permitted_attributes)
    end

    # Adds a policy check for the community
    def authorize_community
      authorize @community
    end

    def permitted_attributes
      %i[
        privacy
      ].concat(BetterTogether::Community.localized_attribute_list)
       .concat(resource_class.extra_permitted_attributes)
    end

    def resource_class
      ::BetterTogether::Community
    end

    def resource_collection
      resource_class.with_translations
    end
  end
end
