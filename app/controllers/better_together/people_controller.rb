# frozen_string_literal: true

module BetterTogether
  class PeopleController < FriendlyResourceController # rubocop:todo Style/Documentation
    before_action :set_person, only: %i[show edit update destroy]
    before_action :authorize_person, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    # GET /people
    def index
      authorize resource_class
      @people = policy_scope(resource_class.with_translations)
    end

    # GET /people/1
    def show
      # Dispatch the background job for tracking the page view
      BetterTogether::Metrics::TrackPageViewJob.perform_later(@person, I18n.locale.to_s) unless bot_request?
    end

    # GET /people/new
    def new
      @person = resource_class.new
      authorize_person
    end

    # POST /people
    def create
      @person = resource_class.new(person_params)
      authorize_person

      if @person.save
        redirect_to @person, only_path: true, notice: 'Person was successfully created.', status: :see_other
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /people/1/edit
    def edit; end

    # PATCH/PUT /people/1
    def update
      ActiveRecord::Base.transaction do
        if @person.update(person_params)
          redirect_to @person, only_path: true, notice: 'Profile was successfully updated.', status: :see_other
        else
          flash.now[:alert] = 'Please address the errors below.'
          render :edit, status: :unprocessable_entity
        end
      end
    end

    # DELETE /people/1
    def destroy
      @person.destroy
      redirect_to people_url, notice: 'Person was successfully deleted.', status: :see_other
    end

    private

    # Adds a policy check for the person
    def authorize_person
      authorize @person
    end

    def id_param
      params[:id] || params[:person_id]
    end

    def set_person
      @person = set_resource_instance
    end

    def person_params
      params.require(:person).permit(
        :name, :description, :profile_image, :slug,
        :profile_image, :cover_image, :remove_profile_image, :remove_cover_image,
        *resource_class.extra_permitted_attributes
      )
    end

    def resource_class
      ::BetterTogether::Person
    end

    def resource_collection
      resource_class.includes(person_platform_memberships: %i[joinable role],
                              person_community_memberships: %i[
                                joinable role
                              ])
    end
  end
end
