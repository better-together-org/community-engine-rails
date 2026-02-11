# frozen_string_literal: true

module BetterTogether
  # ActionCable channel for real-time conversation message delivery.
  #
  # Security rationale (audit finding H5):
  #   Conversations contain private messages between specific participants.
  #   Without an authorization check, any authenticated user who knew (or guessed)
  #   a conversation ID could subscribe and receive every message in real time —
  #   a horizontal privilege-escalation / data-leak vulnerability.
  #   The participant membership check below ensures only conversation participants
  #   can open a WebSocket stream for that conversation.
  class ConversationsChannel < ApplicationCable::Channel
    def subscribed
      conversation = BetterTogether::Conversation.find(params[:id])

      # Only allow participants to receive real-time messages
      if conversation.participants.exists?(id: current_person.id)
        stream_for conversation
      else
        reject
      end
    end

    def unsubscribed
      # Any cleanup needed when channel is unsubscribed
    end
  end
end
