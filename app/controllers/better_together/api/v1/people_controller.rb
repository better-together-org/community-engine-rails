# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for people
      # Provides API equivalent functionality to BetterTogether::PeopleController
      class PeopleController < JSONAPI::ResourceController
        before_action :authenticate_user!, except: %i[index show]

        # Custom /people/me endpoint - equivalent to HTML controller's me? logic
        def me
          person = current_user.person
          authorize person

          render jsonapi: person, class: { Person: PersonResource }
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
      end
    end
  end
end
