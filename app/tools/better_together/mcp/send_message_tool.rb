# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to send a message in an existing conversation (write tool)
    # Requires authentication and conversation participation
    class SendMessageTool < ApplicationTool
      description 'Send a message to an existing conversation'

      arguments do
        required(:conversation_id).filled(:string).description('UUID of the conversation')
        required(:content).filled(:string).description('Message content text')
      end

      # Send a message to a conversation
      # @param conversation_id [String] UUID of the conversation
      # @param content [String] Message content
      # @return [String] JSON with sent message or error
      def call(conversation_id:, content:)
        return auth_required_response unless current_user

        with_timezone_scope do
          conversation = find_conversation(conversation_id)
          return conversation_error unless conversation

          message = create_message(conversation, content)
          result = build_result(message)

          log_invocation('send_message', { conversation_id: conversation_id }, result.bytesize)
          result
        end
      end

      private

      def auth_required_response
        JSON.generate({ error: 'Authentication required' })
      end

      def conversation_error
        JSON.generate({ error: 'Conversation not found or not a participant' })
      end

      def find_conversation(conversation_id)
        person = current_user.person
        return nil unless person

        BetterTogether::Conversation
          .joins(:conversation_participants)
          .where(better_together_conversation_participants: { person_id: person.id })
          .find_by(id: conversation_id)
      end

      def create_message(conversation, content)
        message = BetterTogether::Message.new(
          conversation: conversation,
          sender: current_user.person,
          content: content
        )
        message.save
        message
      end

      def build_result(message)
        if message.persisted?
          JSON.generate(success_response(message))
        else
          JSON.generate({ error: 'Failed to send message', details: message.errors.full_messages })
        end
      end

      def success_response(message)
        {
          id: message.id,
          conversation_id: message.conversation_id,
          content: message.content.to_plain_text,
          sent_at: message.created_at&.iso8601,
          sender_name: message.sender&.name
        }
      end
    end
  end
end
