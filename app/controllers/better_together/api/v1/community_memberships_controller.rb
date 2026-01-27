# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for community memberships (PersonCommunityMembership)
      # Provides API equivalent functionality to manage community membership relationships
      # Memberships link people to communities with specific roles and status
      class CommunityMembershipsController < JSONAPI::ResourceController
        before_action :authenticate_user!

        # GET /api/v1/community_memberships
        # Lists memberships user has permission to view
        # Policy scope filters to:
        # - User's own memberships
        # - Memberships in communities where user is member/organizer
        # - All memberships (for platform managers)
        def index
          # Policy scope applied automatically via context method
          # Same authorization logic as viewing members in HTML interface
          super
        end

        # GET /api/v1/community_memberships/:id
        # Shows specific membership details
        # Authorization allows viewing:
        # - Own membership
        # - Memberships in communities where user is member/organizer
        def show
          # Authorization via Pundit policy
          # Same visibility rules as HTML interface
          super
        end

        # POST /api/v1/community_memberships
        # Creates new community membership
        # Used for:
        # - Accepting invitations
        # - Community organizers adding members
        # - Platform managers managing memberships
        def create
          # Authorization via Pundit policy
          # Validates community access and role assignment permissions
          # Same creation logic as HTML interface
          super
        end

        # PATCH/PUT /api/v1/community_memberships/:id
        # Updates existing membership
        # Allows changing:
        # - Membership status (pending, active, suspended)
        # - Assigned role (if user has permission)
        def update
          # Authorization via Pundit policy
          # Community organizers can update member roles/status
          # Same update logic as HTML interface
          super
        end

        # DELETE /api/v1/community_memberships/:id
        # Removes community membership
        # Allows:
        # - Users leaving communities
        # - Community organizers removing members
        # - Platform managers managing memberships
        def destroy
          # Authorization via Pundit policy
          # Same destruction rules as HTML interface
          super
        end
      end
    end
  end
end
