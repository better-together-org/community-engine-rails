# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to list conversations for the current user
    # Scoped to conversations where the user is a participant
    class ListConversationsTool < ApplicationTool
      description 'List conversations the current user participates in'

      arguments do
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      # List conversations for the current user
      # @param limit [Integer] Maximum results (default: 20)
      # @return [String] JSON array of conversation objects
      def call(limit: 20)
        with_timezone_scope do
          person = agent
          return auth_required_response unless person

          conversations = fetch_conversations(person, limit: limit)

          result = JSON.generate(conversations.map { |c| serialize_conversation(c) })
          log_invocation('list_conversations', { limit: limit }, result.bytesize)
          result
        end
      end

      private

      def auth_required_response
        result = JSON.generate({ error: 'Authentication required to view conversations' })
        log_invocation('list_conversations', {}, result.bytesize)
        result
      end

      def fetch_conversations(person, limit:)
        BetterTogether::Conversation
          .joins(:conversation_participants)
          .where(better_together_conversation_participants: { person_id: person.id })
          .includes(:creator, :participants)
          .order(updated_at: :desc)
          .limit([limit, 100].min)
      end

      def serialize_conversation(conversation)
        {
          id: conversation.id,
          title: conversation.title,
          creator_name: conversation.creator&.name,
          participant_count: conversation.participants.size,
          participant_names: conversation.participants.map(&:name),
          last_updated: conversation.updated_at.in_time_zone.iso8601,
          created_at: conversation.created_at.in_time_zone.iso8601
        }
      end
    end
  end
end
