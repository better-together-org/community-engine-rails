# frozen_string_literal: true

module BetterTogether
  # handles managing messages
  class MessagesController < ApplicationController
    before_action :authenticate_user!
    before_action :disallow_robots
    before_action :set_conversation

    def create
      @message = @conversation.messages.build(message_params)
      @message.sender = helpers.current_person
      return unless @message.save

      # Noticed notification
      notify_participants(@message)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to conversation_path(@conversation) }
      end
    end

    private

    def set_conversation
      @conversation = Conversation.find(params[:conversation_id])
    end

    def message_params
      params.require(:message).permit(*BetterTogether::Message.permitted_attributes)
    end

    def notify_participants(message)
      # Get all participants except the sender
      recipients = message.conversation.participants.where.not(id: message.sender_id)

      # Pass the array of recipients to the notification
      BetterTogether::NewMessageNotifier.with(record: message,
                                              conversation_id: message.conversation_id).deliver_later(recipients)
    end

    def broadcast_to_recipients(message, recipients)
      recipients.each do |recipient|
        html = ApplicationController.render(
          partial: 'better_together/messages/message',
          locals: { message: message, me: recipient == message.sender }
        )

        BetterTogether::ConversationsChannel.broadcast_to(
          message.conversation,
          html: html
        )
      end
    end
  end
end
