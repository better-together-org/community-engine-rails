# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes the Conversation class for JSONAPI
      # Conversations use encrypted title - serialization works transparently
      class ConversationResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Conversation'

        # Standard attributes
        attributes :title

        # Relationships
        has_one :creator, class_name: 'Person'
        has_many :participants, class_name: 'Person'
        has_many :messages

        # Scope conversations to only those the current user participates in
        def self.records(options = {})
          context = options[:context]
          person = context&.dig(:current_person)

          if person
            super.joins(:conversation_participants)
                 .where(better_together_conversation_participants: { person_id: person.id })
                 .distinct
          else
            super.none
          end
        end

        # Creatable and updatable fields
        def self.creatable_fields(context)
          super - %i[creator]
        end

        def self.updatable_fields(_context)
          %i[title] # Only title can be updated
        end
      end
    end
  end
end
