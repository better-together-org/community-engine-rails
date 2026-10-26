# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for people
      # Provides API equivalent functionality to BetterTogether::PeopleController
      class PeopleController < BetterTogether::Api::ApplicationController
        # Membership relationships are private to the person and staff who can
        # update them (see PersonResource::PRIVATE_FIELDS).
        PRIVATE_RELATIONSHIPS = %w[communities person_community_memberships].freeze

        before_action :restrict_private_relationships,
                      only: %i[show_relationship get_related_resources get_related_resource]

        # Custom /people/me endpoint - equivalent to HTML controller's me? logic
        # Sets the ID param to current user's person and processes as a standard show request
        def me
          return head(:unauthorized) unless current_user&.person

          params[:id] = current_user.person.id
          params[:action] = 'show'
          process_request
        end

        # GET /api/v1/people
        # Equivalent to HTML index action with policy_scope filtering
        def index
          # Policy scope is applied automatically via context method in ApplicationController
          # Same authorization logic as HTML controller: permits users with 'list_person' permission
          super
        end

        # GET /api/v1/people/:id
        # Equivalent to HTML show action
        # Authorization allows viewing own profile or users with 'read_person' permission
        def show
          # Authorization happens via context method in ApplicationController
          # Same logic as HTML controller's show action
          super
        end

        # POST /api/v1/people
        # Equivalent to HTML create action
        # Requires authentication and 'create_person' permission
        def create
          # Authorization happens via context method in ApplicationController
          # Same validation and creation logic as HTML controller
          super
        end

        # PATCH/PUT /api/v1/people/:id
        # Equivalent to HTML update action
        # Allows updating own profile or users with 'update_person' permission
        def update
          # Authorization happens via context method in ApplicationController
          # Same update logic as HTML controller
          super
        end

        # DELETE /api/v1/people/:id
        # Equivalent to HTML destroy action
        # Requires 'delete_person' permission
        def destroy
          # Authorization happens via context method in ApplicationController
          # Same destruction logic as HTML controller
          super
        end

        private

        def restrict_private_relationships
          return unless PRIVATE_RELATIONSHIPS.include?(params[:relationship].to_s)

          person = BetterTogether::Person.find_by(id: params[:person_id] || params[:id])
          return if person && current_user && BetterTogether::PersonPolicy.new(current_user, person).update?

          head :not_found
        end

        def enforce_policy_use
          # JSONAPI::ResourceController applies policy scope internally but
          # does not flag policy usage for pundit-resources enforcement.
          # Avoid raising after_action errors for successful JSONAPI responses.
        end
      end
    end
  end
end
