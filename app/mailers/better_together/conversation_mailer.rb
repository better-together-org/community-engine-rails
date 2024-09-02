module BetterTogether
  class ConversationMailer < ApplicationMailer
    def new_message_notification
      @platform = BetterTogether::Platform.find_by(host: true)
      @message = params[:message]
      @conversation = @message.conversation
      @recipient = params[:recipient]
      @sender = @message.sender

      Time.use_zone(@recipient.time_zone) do
        I18n.with_locale(@recipient.locale) do
          mail(to: @recipient.email, subject: t('better_together.conversation_mailer.new_message_notification.subject', platform: @platform.name, conversation: @conversation.title))
        end
      end
    end
  end
end
