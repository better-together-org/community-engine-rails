# frozen_string_literal: true

module BetterTogether
  class PlatformsController < FriendlyResourceController
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
    def show
      authorize @platform
    end

    # GET /platforms/new
    def new
      @platform = ::BetterTogether::Platform.new
      authorize_platform
    end

    # GET /platforms/1/edit
    def edit
      authorize @platform
    end

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
      authorize @platform
      if @platform.update(platform_params)
        redirect_to @platform, notice: 'Platform was successfully updated.', status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /platforms/1
    def destroy
      authorize @platform
      @platform.destroy
      redirect_to platforms_url, notice: 'Platform was successfully destroyed.', status: :see_other
    end

    private

    def set_platform
      @platform = set_resource_instance
    end

    def platform_params
      permitted_attributes = %i[
        slug url time_zone privacy
      ]
      css_block_attrs = [{ css_block_attributes: %i[id type
                                                    identifier] + BetterTogether::Content::Css.extra_permitted_attributes + BetterTogether::Content::Css.localized_attribute_list }]
      params.require(:platform).permit(permitted_attributes, *settings_attributes, *locale_attributes, *css_block_attrs)
    end

    # Adds a policy check for the platform
    def authorize_platform
      authorize @platform
    end

    def locale_attributes
      localized_attributes = BetterTogether::Platform.mobility_attributes.map do |attribute|
        I18n.available_locales.map do |locale|
          :"#{attribute}_#{locale}"
        end
      end

      localized_attributes.flatten
    end

    def settings_attributes
      %i[requires_invitation]
    end

    def resource_class
      ::BetterTogether::Platform
    end

    def resource_collection
      resource_class.includes(:invitations, { person_platform_memberships: %i[member role] })
    end
  end
end
