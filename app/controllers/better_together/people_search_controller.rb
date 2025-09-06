# frozen_string_literal: true

module BetterTogether
  class PeopleSearchController < ApplicationController
    before_action :authenticate_user!
    after_action :verify_authorized

    def index
      authorize :people_search, :search?

      @people = search_people

      respond_to do |format|
        format.json { render json: people_for_json }
      end
    end

    private

    def search_people
      return BetterTogether::Person.none if search_query.blank?

      # Get the community context - search within the current user's primary community
      community = helpers.current_person&.primary_community
      return BetterTogether::Person.none unless community

      # Search within community members, excluding the current user
      community.members
               .where.not(id: helpers.current_person.id)
               .where(
                 'better_together_people.name ILIKE :query OR better_together_people.identifier ILIKE :query',
                 query: "%#{search_query}%"
               )
               .limit(10)
               .order(:name)
    end

    def people_for_json
      @people.map do |person|
        {
          id: person.id,
          name: person.name,
          identifier: person.identifier,
          avatar_url: helpers.profile_image_url(person, size: 50)
        }
      end
    end

    def search_query
      @search_query ||= params[:q].to_s.strip
    end
  end
end
