# frozen_string_literal: true

module BetterTogether
  # Sends email notifications for conversation activities
  class ConversationMailer < ApplicationMailer
    def new_message_notification # rubocop:todo Metrics/MethodLength
      @platform = BetterTogether::Platform.find_by(host: true)
      @message = params[:message]
      @conversation = @message.conversation
      @recipient = params[:recipient]
      @sender = @message.sender

      # Override time zone and locale if necessary
      self.locale = @recipient.locale
      self.time_zone = @recipient.time_zone

      mail(to: @recipient.email,
           subject: t('better_together.conversation_mailer.new_message_notification.subject',
                      platform: @platform.name,
                      conversation: @conversation.title))
    end
  end
end
