# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for messages
      # Messages are scoped to conversations the current user participates in
      class MessagesController < BetterTogether::Api::ApplicationController
        # GET /api/v1/messages
        # Returns messages from conversations the user participates in
        def index
          super
        end

        # GET /api/v1/messages/:id
        # Requires the user to be a participant in the message's conversation
        def show
          super
        end

        # POST /api/v1/messages
        # Creates a new message in a conversation
        # Current user's person is set as sender
        def create
          super
        end
      end
    end
  end
end
