# frozen_string_literal: true

module BetterTogether
  # allows for communication between people
  class Message < ApplicationRecord
    belongs_to :conversation, touch: true
    belongs_to :sender, class_name: 'BetterTogether::Person'

    validates :content, presence: true

    after_create_commit do
      # Broadcast the new message to the conversation
      ::BetterTogether::MessagesChannel.broadcast_to(conversation, {
                                                       content:,
                                                       person: sender.identifier,
                                                       created_at: created_at.strftime('%H:%M %d-%m-%Y')
                                                     })
    end
  end
end
