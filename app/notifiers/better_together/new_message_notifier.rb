# frozen_string_literal: true

module BetterTogether
  # Uses Noticed gem to create and dispatch notifications for new messages
  class NewMessageNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message
    # deliver_by :action_cable, channel: 'BetterTogether::MessagesChannel', message: :build_message
    deliver_by :email, mailer: 'BetterTogether::ConversationMailer', method: :new_message_notification,
                       params: :email_params do |config|
      # config.wait = 15.minutes
      config.if = -> { send_email_notification? }
    end

    validates :record, presence: true

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

      def send_email_notification?
        recipient.email.present? && recipient.notify_by_email && should_send_email?
      end

      def should_send_email?
        # Check for unread notifications for the recipient for the record's conversation
        unread_notifications = recipient.notifications.where(
          event_id: BetterTogether::NewMessageNotifier.where(params: { conversation_id: conversation.id }).select(:id),
          read_at: nil
        ).order(created_at: :desc)

        if unread_notifications.none?
          # If the recipient has read their notifications, do not send
          false
        else
          # Only send one email per unread notifications per conversation
          message.id == unread_notifications.last.event.record_id
        end
      end
    end

    def identifier
      conversation.id
    end

    def url
      ::BetterTogether::Engine.routes.url_helpers.conversation_url(conversation, locale: I18n.locale)
    end

    def title
      I18n.t('better_together.notifications.new_message.title', sender: message.sender,
                                                                conversation: conversation.title)
    end

    def body
      I18n.t('better_together.notifications.new_message.content', content: message.content.to_plain_text.truncate(100))
    end

    def build_message(notification)
      {
        title:,
        body:,
        identifier:,
        url:,
        unread_count: notification.recipient.notifications.unread.count
      }
    end

    def email_params(notification)
      { message: notification.record }
    end
  end
end
