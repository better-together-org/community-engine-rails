# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes the Message class for JSONAPI
      # Message content is encrypted at rest via has_rich_text :content, encrypted: true
      class MessageResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Message'

        # Standard attributes
        attribute :content_plain_text

        # Relationships
        has_one :sender, class_name: 'Person'
        has_one :conversation

        # Custom attribute: return plain text of rich text content
        def content_plain_text
          @model.content&.to_plain_text
        end

        # Scope messages to conversations the current user participates in
        def self.records(options = {})
          context = options[:context]
          person = context&.dig(:current_person)

          if person
            conversation_ids = ::BetterTogether::ConversationParticipant
                               .where(person_id: person.id)
                               .select(:conversation_id)
            super.where(conversation_id: conversation_ids)
          else
            super.none
          end
        end

        # Creatable fields
        def self.creatable_fields(_context)
          %i[content conversation sender]
        end

        def self.updatable_fields(_context)
          [] # Messages are immutable once sent
        end
      end
    end
  end
end
