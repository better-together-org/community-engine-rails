# frozen_string_literal: true

# app/controllers/better_together/people_controller.rb
module BetterTogether
  # Responds to requests for people
  class PeopleController < ApplicationController
    before_action :set_person

    def show; end

    def edit; end

    def update
      ActiveRecord::Base.transaction do
        @person.update!(person_params)
        redirect_to @person, notice: 'Profile was successfully updated.'
      end
    rescue ActiveRecord::RecordInvalid
      flash.now[:alert] = 'Please address the errors below.'
      render :edit
    end

    private

    def set_person
      @person = helpers.current_person
    end

    def person_params
      params.require(:person).permit(:name, :description, :profile_image)
    end
  end
end
