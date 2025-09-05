# frozen_string_literal: true

module BetterTogether
  class PeopleController < FriendlyResourceController # rubocop:todo Style/Documentation, Metrics/ClassLength
    before_action :set_person, only: %i[show edit update destroy]

    # GET /people
    def index
      @people = resource_collection
    end

    # GET /people/1
    def show
      # Preload authored pages for the profile's Pages tab, with translations and background images
      @authored_pages = policy_scope(@person.authored_pages)
                        .includes(
                          :string_translations,
                          blocks: { background_image_file_attachment: :blob }
                        )
      
      # Preload calendar associations to avoid N+1 queries
      @person.preload_calendar_associations!
    end

    # GET /people/new
    def new
      @person = resource_class.new
      authorize_person
    end

    # POST /people
    def create # rubocop:todo Metrics/MethodLength
      @person = resource_class.new(person_params)
      authorize_person

      if @person.save
        redirect_to @person, only_path: true,
                             notice: t('flash.generic.created', resource: t('resources.person')),
                             status: :see_other
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @person }
            )
          end
          format.html { render :new, status: :unprocessable_content }
        end
      end
    end

    # GET /people/1/edit
    def edit; end

    # PATCH/PUT /people/1
    def update # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      ActiveRecord::Base.transaction do
        # Ensure boolean toggles are respected even when unchecked ("0")
        toggles = {}
        person_params_raw = params[:person] || {}
        if person_params_raw.key?(:notify_by_email)
          toggles[:notify_by_email] = ActiveModel::Type::Boolean.new.cast(person_params_raw[:notify_by_email])
        end
        if person_params_raw.key?(:show_conversation_details)
          toggles[:show_conversation_details] = ActiveModel::Type::Boolean.new.cast(person_params_raw[:show_conversation_details])
        end

        if @person.update(person_params.merge(toggles))
          redirect_to @person, only_path: true,
                               notice: t('flash.generic.updated', resource: t('resources.profile', default: t('resources.person'))), # rubocop:disable Layout/LineLength
                               status: :see_other
        else
          flash.now[:alert] = 'Please address the errors below.'
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @person }
              )
            end
            format.html { render :edit, status: :unprocessable_content }
          end
        end
      end
    end

    # DELETE /people/1
    def destroy
      @person.destroy
      redirect_to people_url, notice: t('flash.generic.destroyed', resource: t('resources.person')),
                              status: :see_other
    end

    protected

    def id_param
      params[:id] || params[:person_id]
    end

    def me?
      id_param == 'me'
    end

    def set_person
      @person = set_resource_instance
    end

    def set_resource_instance
      if me?
        @resource = helpers.current_person
      else
        # Avoid friendly_id history DB quirks by using Mobility translations or identifier first
        @resource = find_by_translatable(translatable_type: resource_class.name, friendly_id: id_param) ||
                    resource_class.find_by(identifier: id_param) ||
                    resource_class.find_by(id: id_param)

        render_not_found and return if @resource.nil?
      end

      @resource
    end

    def person_params
      params.require(:person).permit(
        :name, :description, :profile_image, :slug, :locale, :notify_by_email,
        :show_conversation_details, :profile_image, :cover_image, :remove_profile_image,
        :remove_cover_image,
        *resource_class.permitted_attributes
      )
    end

    def resource_class
      ::BetterTogether::Person
    end

    def resource_collection # rubocop:todo Metrics/MethodLength
      policy_scope(resource_class.with_translations.with_attached_profile_image.with_attached_cover_image.includes(
                     contact_detail: %i[phone_numbers email_addresses website_links addresses social_media_accounts],
                     person_platform_memberships: {
                       joinable: [:string_translations, { profile_image_attachment: :blob }],
                       role: [:string_translations]
                     },
                     person_community_memberships: {
                       joinable: [:string_translations, { profile_image_attachment: :blob }],
                       role: [:string_translations]
                     }
                   ))
    end
  end
end
