# frozen_string_literal: true

module BetterTogether
  # allows for communication between people
  class Message < ApplicationRecord
    belongs_to :conversation, touch: true
    belongs_to :sender, class_name: 'BetterTogether::Person'

    has_rich_text :content, encrypted: true

    validates :content, presence: true

    after_create_commit -> { broadcast_append_later_to conversation, target: 'conversation_messages' }

    # Attributes permitted for strong parameters
    def self.permitted_attributes
      # include id and _destroy for nested attributes handling
      %i[id content e2e_encrypted e2e_version e2e_protocol _destroy]
    end

    # True when this message was encrypted client-side with Signal Protocol.
    # The server stores the ciphertext but cannot decrypt it.
    def e2e?
      e2e_encrypted?
    end
  end
end
