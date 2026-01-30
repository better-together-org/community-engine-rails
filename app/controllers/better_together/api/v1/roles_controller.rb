# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for roles (read-only via API)
      # Provides API equivalent functionality to BetterTogether::RolesController
      # NOTE: HTML controller allows full CRUD for platform managers
      # API restricts to read-only operations - roles managed via HTML interface
      class RolesController < BetterTogether::Api::ApplicationController
        before_action :authenticate_user!

        # GET /api/v1/roles
        # Equivalent to HTML index action
        # Lists all roles - policy scope filters based on permissions
        def index
          # Policy scope applied automatically via context method
          # Platform managers can see all roles
          # Other users see roles relevant to their context
          super
        end

        # GET /api/v1/roles/:id
        # Equivalent to HTML show action
        # Shows role details if user has permission
        def show
          # Authorization via Pundit policy
          # Same visibility rules as HTML controller
          super
        end

        # POST /api/v1/roles - NOT AVAILABLE
        # PATCH/PUT /api/v1/roles/:id - NOT AVAILABLE
        # DELETE /api/v1/roles/:id - NOT AVAILABLE
        #
        # Roles are read-only via API for security
        # HTML controller allows full CRUD for platform managers
        # create, update, destroy actions are blocked by RoleResource.creatable_fields returning []
        # To manage roles, use the HTML interface at /:locale/host/roles
      end
    end
  end
end
