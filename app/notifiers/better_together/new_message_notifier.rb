# frozen_string_literal: true

# To deliver this notification:
#
# BetterTogether::NewMessageNotifier.with(record: @post, message: "New post").deliver(User.all)

module BetterTogether
  # Uses Noticed gem to create and dispatch notifications for new messages
  class NewMessageNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::MessagesChannel', message: :build_message
    deliver_by :email, mailer: 'BetterTogether::ConversationMailer', method: :new_message_notification,
                       params: :email_params do |config|
      config.if = -> { recipient.email.present? }
    end

    validates :record, presence: true

    # Define required params
    # param :message

    # Helper method to simplify calling params
    def message
      record
    end

    def conversation
      message.conversation
    end

    def sender
      message.sender
    end

    notification_methods do
      delegate :conversation, to: :event
      delegate :message, to: :event
      delegate :sender, to: :event
      delegate :url, to: :event
    end

    def url
      ::BetterTogether::Engine.routes.url_helpers.conversation_path(conversation)
    end

    def title
      I18n.t('notifications.new_message.title', conversation: conversation.title)
    end

    def content
      I18n.t('notifications.new_message.content', sender: sender.identifier, message: message.content)
    end

    def build_message(_notification)
      {
        title:,
        content:,
        url:
      }
    end

    def email_params(notification)
      { message: notification.record }
    end
  end
end
