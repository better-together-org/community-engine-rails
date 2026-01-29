# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for communities
      # Provides API equivalent functionality to BetterTogether::CommunitiesController
      class CommunitiesController < BetterTogether::Api::ApplicationController
        # GET /api/v1/communities
        # Equivalent to HTML index action
        # Shows all communities - policy scope filters by privacy and permissions
        def index
          # Policy scope applied automatically via context method
          # Filters communities based on:
          # - Public communities (visible to all)
          # - Private communities (only if user is member or has invitation)
          # Same authorization logic as HTML controller
          super
        end

        # GET /api/v1/communities/:id
        # Equivalent to HTML show action
        # Authorization checks:
        # - Public communities: always visible
        # - Private communities: requires membership, creator status, or valid invitation
        def show
          # Authorization via Pundit policy - same logic as HTML controller
          # Supports invitation token validation for private communities
          super
        end

        # POST /api/v1/communities
        # Equivalent to HTML create action
        # Requires authentication and either:
        # - 'manage_platform' permission, or
        # - 'create_community' permission
        # Sets creator to current user's person
        def create
          # Authorization via Pundit policy
          # Creator is automatically set via JSONAPI resource configuration
          # Same validation and creation logic as HTML controller
          super
        end

        # PATCH/PUT /api/v1/communities/:id
        # Equivalent to HTML update action
        # Requires authentication and either:
        # - 'manage_platform' permission, or
        # - 'update_community' permission for specific community
        def update
          # Authorization via Pundit policy
          # Same update logic and validations as HTML controller
          super
        end

        # DELETE /api/v1/communities/:id
        # Equivalent to HTML destroy action
        # Requires authentication and either:
        # - 'manage_platform' permission, or
        # - 'destroy_community' permission for specific community
        # Cannot delete protected or host communities
        def destroy
          # Authorization via Pundit policy
          # Same destruction rules as HTML controller (no protected/host deletion)
          super
        end
      end
    end
  end
end
