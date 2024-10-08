# frozen_string_literal: true

module BetterTogether
  # Uses Noticed gem to create and dispatch notifications for new messages
  class NewMessageNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::MessagesChannel', message: :build_message
    deliver_by :email, mailer: 'BetterTogether::ConversationMailer', method: :new_message_notification,
                       params: :email_params do |config|
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
        recipient.email.present? && should_send_email?
      end

      def should_send_email?
        # Find the events related to the conversation
        related_event_ids = Noticed::Event.where(type: 'BetterTogether::NewMessageNotifier', params: { conversation_id: conversation.id })
                                          .pluck(:id)
      
        # Check for unread notifications for the recipient related to these events
        unread_notifications_count = recipient.notifications
                                              .where(event_id: related_event_ids, read_at: nil)
                                              .count
      
        if unread_notifications_count.zero?
          # No unread notifications, send the email
          true
        else
          # Optional: Implement a time-based delay or other conditions
          last_email_sent_at = recipient.notifications
                                        .where(event_id: related_event_ids)
                                        .order(created_at: :desc)
                                        .pluck(:created_at)
                                        .first
      
          return true if last_email_sent_at.blank? # Send if no previous email sent
      
          # Send email only if more than 30 minutes have passed since the last one
          last_email_sent_at < 30.minutes.ago
        end
      end
      

    end

    def url
      ::BetterTogether::Engine.routes.url_helpers.conversation_path(conversation, locale: I18n.locale)
    end

    def title
      I18n.t('notifications.new_message.title', conversation: conversation.title)
    end

    def content
      I18n.t('notifications.new_message.content', sender: sender.identifier, message: message.content)
    end

    def build_message(_notification)
      {
        title: title,
        content: content,
        url: url
      }
    end

    def email_params(notification)
      { message: notification.record }
    end
  end
end
