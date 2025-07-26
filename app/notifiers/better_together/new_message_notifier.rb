# frozen_string_literal: true

module BetterTogether
  # Uses Noticed gem to create and dispatch notifications for new messages
  class NewMessageNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message
    # deliver_by :action_cable, channel: 'BetterTogether::MessagesChannel', message: :build_message
    deliver_by :email, mailer: 'BetterTogether::ConversationMailer', method: :new_message_notification,
                       params: :email_params do |config|
      config.wait = 15.minutes
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

      # rubocop:todo Metrics/MethodLength
      def should_send_email? # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        # Find the events related to the conversation
        related_event_ids = BetterTogether::NewMessageNotifier.where(params: { conversation_id: conversation.id })
                                                              .pluck(:id)

        # Check for unread notifications for the recipient related to these events
        unread_notifications = recipient.notifications
                                        .where(event_id: related_event_ids, read_at: nil)

        if unread_notifications.empty? || (unread_notifications.last.created_at <= 1.day.ago)
          # No unread recent notifications, send the email
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
      # rubocop:enable Metrics/MethodLength
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

    def build_message(_notification)
      {
        title:,
        body:,
        identifier:,
        url:
      }
    end

    def email_params(notification)
      { message: notification.record }
    end
  end
end
