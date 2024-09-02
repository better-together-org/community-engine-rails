module BetterTogether
  # Preview all emails at http://localhost:3000/rails/mailers/better_together/conversation_mailer_mailer
  class ConversationMailerPreview < ActionMailer::Preview

    # Preview this email at http://localhost:3000/rails/mailers/better_together/conversation_mailer_mailer/new_message_notification
    def new_message_notification
      ConversationMailer.new_message_notification
    end

  end
end
