# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for events
      # Provides API equivalent functionality to BetterTogether::EventsController
      class EventsController < BetterTogether::Api::ApplicationController
        # GET /api/v1/events
        # Policy scope filters by privacy and permissions
        # Supports scope filter: upcoming, past, ongoing, draft, scheduled
        def index
          super
        end

        # GET /api/v1/events/:id
        # Authorization checks via EventPolicy:
        # - Public + scheduled events: always visible
        # - Private events: requires creator status, host membership, or invitation
        def show
          super
        end

        # POST /api/v1/events
        # Requires authentication and either:
        # - 'manage_platform' permission, or
        # - Event host membership
        def create
          super
        end

        # PATCH/PUT /api/v1/events/:id
        # Requires authentication and either:
        # - Creator or platform manager, or
        # - Event host membership
        def update
          super
        end

        # DELETE /api/v1/events/:id
        # Requires authentication and creator/manager status
        def destroy
          super
        end
      end
    end
  end
end
