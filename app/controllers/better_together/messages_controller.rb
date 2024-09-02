module BetterTogether
  class MessagesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_conversation
  
    def create
      @message = @conversation.messages.build(message_params)
      @message.sender = helpers.current_person
      if @message.save
        # Noticed notification
        notify_participants(@message)

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to conversation_path(@conversation) }
        end
      else
        # handle errors
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
  
      # Pass the array of recipients to the notification
      BetterTogether::NewMessageNotifier.with(record: message).deliver(recipients)
    end
  end
  
end
