# frozen_string_literal: true

module BetterTogether
  class PlatformsController < FriendlyResourceController # rubocop:todo Style/Documentation
    before_action :set_platform, only: %i[show edit update destroy]
    before_action :authorize_platform, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    before_action only: %i[show], if: -> { Rails.env.development? } do
      # Make sure that all Platform Invitation subclasses are loaded in dev to generate new block buttons
      ::BetterTogether::PlatformInvitation.load_all_subclasses
    end

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
    def create # rubocop:todo Metrics/MethodLength
      @platform = ::BetterTogether::Platform.new(platform_params)
      authorize_platform

      if @platform.save
        redirect_to @platform, notice: t('flash.generic.created', resource: t('resources.platform'))
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @platform }
            )
          end
          format.html { render :new, status: :unprocessable_content }
        end
      end
    end

    # PATCH/PUT /platforms/1
    def update # rubocop:todo Metrics/MethodLength
      authorize @platform
      if @platform.update(platform_params)
        redirect_to @platform, notice: t('flash.generic.updated', resource: t('resources.platform')), status: :see_other
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @platform }
            )
          end
          format.html { render :edit, status: :unprocessable_content }
        end
      end
    end

    # DELETE /platforms/1
    def destroy
      authorize @platform
      @platform.destroy
      redirect_to platforms_url, notice: t('flash.generic.destroyed', resource: t('resources.platform')),
                                 status: :see_other
    end

    private

    def set_platform
      @platform = set_resource_instance
    end

    def platform_params # rubocop:todo Metrics/MethodLength
      permitted_attributes = %i[
        slug url time_zone privacy
      ]
      css_block_attrs = [{ css_block_attributes: %i[id type identifier] +
        BetterTogether::Content::Css.extra_permitted_attributes +
        BetterTogether::Content::Css.localized_attribute_list }]

      params.require(:platform).permit(
        permitted_attributes,
        *settings_attributes,
        *locale_attributes,
        *css_block_attrs
      )
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
