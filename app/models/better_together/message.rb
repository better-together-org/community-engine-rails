module BetterTogether
  class Message < ApplicationRecord
    belongs_to :conversation
    belongs_to :sender, class_name: 'BetterTogether::Person'

    validates :content, presence: true

    after_create_commit do
      # Broadcast the new message to the conversation
      ::BetterTogether::MessagesChannel.broadcast_to(conversation, {
        content: content,
        person: sender.identifier,
        created_at: created_at.strftime('%H:%M %d-%m-%Y')
      })
    end
  end
end
