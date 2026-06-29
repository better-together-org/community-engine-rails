# frozen_string_literal: true

module BetterTogether
  # Handles creation and response (accept/decline) for messaging permission requests.
  class MessageRequestsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_message_request, only: %i[show accept decline]
    after_action :verify_authorized

    def index
      @message_requests = policy_scope(MessageRequest)
                          .where(recipient: current_person)
                          .pending
                          .order(created_at: :desc)
      authorize MessageRequest
    end

    def show
      authorize @message_request
    end

    def create
      @message_request = MessageRequest.new(message_request_params.merge(
                                              sender: current_person,
                                              platform: current_platform
                                            ))
      authorize @message_request

      if @message_request.save
        redirect_back fallback_location: conversations_path,
                      notice: t('better_together.message_requests.sent')
      else
        redirect_back fallback_location: conversations_path,
                      alert: @message_request.errors.full_messages.to_sentence
      end
    end

    def accept
      authorize @message_request
      @message_request.accept!
      redirect_to conversations_path, notice: t('better_together.message_requests.accepted')
    end

    def decline
      authorize @message_request
      @message_request.decline!
      redirect_back fallback_location: message_requests_path,
                    notice: t('better_together.message_requests.declined')
    end

    private

    def set_message_request
      @message_request = MessageRequest.find(params[:id])
    end

    def message_request_params
      params.require(:message_request).permit(:recipient_id, :note)
    end
  end
end
