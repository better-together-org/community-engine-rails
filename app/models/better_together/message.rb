# frozen_string_literal: true

module BetterTogether
  # allows for communication between people
  class Message < PlatformRecord
    include Reportable
    include Broadcastable

    belongs_to :conversation, touch: true
    belongs_to :sender, class_name: 'BetterTogether::Person', inverse_of: :sent_messages

    has_rich_text :content, encrypted: true

    validates :content, presence: true

    broadcasts_async_to :conversation, target: 'conversation_messages'

    # Attributes permitted for strong parameters
    def self.permitted_attributes
      # include id and _destroy for nested attributes handling
      %i[id content _destroy]
    end
  end
end
