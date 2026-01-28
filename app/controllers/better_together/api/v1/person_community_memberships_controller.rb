# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for person community memberships (PersonCommunityMembership)
      # Provides API functionality to manage community membership relationships
      class PersonCommunityMembershipsController < BetterTogether::Api::ApplicationController
        before_action :authenticate_user!

        # GET /api/v1/person_community_memberships
        def index
          super
        end

        # GET /api/v1/person_community_memberships/:id
        def show
          super
        end

        # POST /api/v1/person_community_memberships
        def create
          super
        end

        # PATCH/PUT /api/v1/person_community_memberships/:id
        def update
          super
        end

        # DELETE /api/v1/person_community_memberships/:id
        def destroy
          super
        end
      end
    end
  end
end
