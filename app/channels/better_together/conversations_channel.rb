# frozen_string_literal: true

module BetterTogether
  # action cable channel for conversations
  class ConversationsChannel < ApplicationCable::Channel
    def subscribed
      conversation = BetterTogether::Conversation.find(params[:id])
      stream_for conversation
    end

    def unsubscribed
      # Any cleanup needed when channel is unsubscribed
    end
  end
end
