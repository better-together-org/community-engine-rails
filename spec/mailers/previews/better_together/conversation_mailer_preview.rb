# frozen_string_literal: true

module BetterTogether
  # Preview all emails at http://localhost:3000/rails/mailers/better_together/conversation_mailer
  # Preview all emails at http://localhost:3000/rails/mailers/better_together/conversation_mailer
  class ConversationMailerPreview < ActionMailer::Preview
    include FactoryBot::Syntax::Methods
    include BetterTogether::ApplicationHelper

    # Preview this email at http://localhost:3000/rails/mailers/better_together/conversation_mailer/new_message_notification
    def new_message_notification
      host_platform || create(:platform)
      sender = create(:user)
      recipient = create(:user)
      conversation = create(:conversation, creator: sender.person)
      message = create(:message, conversation: conversation, sender: sender.person)

      ConversationMailer.with(message: message, recipient: recipient.person)
                        .new_message_notification
    end
  end
end
