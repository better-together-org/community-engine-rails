# frozen_string_literal: true

module BetterTogether
  class PeopleController < FriendlyResourceController # rubocop:todo Style/Documentation
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
        redirect_to @person, only_path: true, notice: 'Person was successfully created.', status: :see_other
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @person }
            )
          end
          format.html { render :new, status: :unprocessable_entity }
        end
      end
    end

    # GET /people/1/edit
    def edit; end

    # PATCH/PUT /people/1
    def update # rubocop:todo Metrics/MethodLength
      ActiveRecord::Base.transaction do
        if @person.update(person_params)
          redirect_to @person, only_path: true, notice: 'Profile was successfully updated.', status: :see_other
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
            format.html { render :edit, status: :unprocessable_entity }
          end
        end
      end
    end

    # DELETE /people/1
    def destroy
      @person.destroy
      redirect_to people_url, notice: 'Person was successfully deleted.', status: :see_other
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
      @resource = if me?
                    helpers.current_person
                  else
                    super
                  end
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
