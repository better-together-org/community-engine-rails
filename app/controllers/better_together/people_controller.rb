# frozen_string_literal: true

module BetterTogether
  class PeopleController < ApplicationController # rubocop:todo Style/Documentation
    before_action :set_person, only: %i[show edit update destroy]
    before_action :authorize_person, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    # GET /people
    def index
      authorize ::BetterTogether::Person
      @people = policy_scope(::BetterTogether::Person.with_translations)
    end

    # GET /people/1
    def show; end

    # GET /people/new
    def new
      @person = ::BetterTogether::Person.new
      authorize_person
    end

    # POST /people
    def create
      @person = ::BetterTogether::Person.new(person_params)
      authorize_person

      if @person.save
        redirect_to @person, notice: 'Person was successfully created.', status: :see_other
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
          redirect_to @person, notice: 'Profile was successfully updated.', status: :see_other
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

    def set_person
      @person = ::BetterTogether::Person.includes(person_platform_memberships: %i[joinable role],
                                                  person_community_memberships: %i[
                                                    joinable role
                                                  ]).friendly.find(params[:id] || params[:person_id])
    end

    def person_params
      params.require(:person).permit(:name, :description, :profile_image, :slug)
    end

    # Adds a policy check for the person
    def authorize_person
      authorize @person
    end
  end
end
