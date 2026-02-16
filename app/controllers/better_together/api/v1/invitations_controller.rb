# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for invitations
      # Provides API access to invitation management
      class InvitationsController < BetterTogether::Api::ApplicationController
        # GET /api/v1/invitations
        # Scoped by InvitationPolicy::Scope
        def index
          super
        end

        # GET /api/v1/invitations/:id
        def show
          super
        end

        # POST /api/v1/invitations
        # Requires invitable management permissions
        def create
          super
        end

        # PATCH /api/v1/invitations/:id
        # Used to accept/decline invitations
        def update
          super
        end
      end
    end
  end
end
