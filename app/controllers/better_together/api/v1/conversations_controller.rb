# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for conversations
      # Conversations are scoped to the current user's participation
      class ConversationsController < BetterTogether::Api::ApplicationController
        # GET /api/v1/conversations
        # Returns only conversations the authenticated user participates in
        def index
          super
        end

        # GET /api/v1/conversations/:id
        # Requires the user to be a participant
        def show
          super
        end

        # POST /api/v1/conversations
        # Creates a new conversation with participants
        # Current user is automatically added as participant
        def create
          super
        end

        # PATCH/PUT /api/v1/conversations/:id
        # Only the creator can update title
        def update
          super
        end
      end
    end
  end
end
