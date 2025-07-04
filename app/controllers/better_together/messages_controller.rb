# frozen_string_literal: true

module BetterTogether
  # handles managing messages
  class MessagesController < ApplicationController
    before_action :authenticate_user!
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
      params.require(:message).permit(:content)
    end

    def notify_participants(message)
      # Get all participants except the sender
      recipients = message.conversation.participants.where.not(id: message.sender_id)

      # Log recipients for debugging
      puts "Recipients for message notification: #{recipients.map(&:id)}"

      # Pass the array of recipients to the notification
      BetterTogether::NewMessageNotifier.with(record: message).deliver_later(recipients)
    end
  end
end
