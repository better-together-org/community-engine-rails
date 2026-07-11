# frozen_string_literal: true

module BetterTogether
  # Notifies a commentable's credited authors (or creator, as a fallback) when someone
  # else comments on their content.
  class CommentAddedNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications do |config|
      config.if = -> { recipient_allows_comment_notifications? }
    end
    deliver_by :email, mailer: 'BetterTogether::CommentMailer', method: :added, params: :email_params,
                       queue: :mailers do |config|
      config.if = -> { recipient_has_email? && recipient_allows_comment_notifications? }
    end

    required_param :comment

    validates :record, presence: true

    def comment
      params[:comment] || record
    end

    def commentable
      comment.commentable
    end

    def commenter_name
      comment.creator&.name || I18n.t('better_together.comments.deleted_author', default: 'A member')
    end

    def title
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.comment_added.title',
          commenter_name:,
          default: '%<commenter_name>s commented on your content'
        )
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t(
          'better_together.notifications.comment_added.body',
          content: comment.content.to_s.truncate(140),
          default: '%<content>s'
        )
      end
    end

    def build_message(notification)
      I18n.with_locale(locale_for_notification(notification)) do
        { title:, body:, url: comment_url }
      end
    end

    def email_params(notification)
      { comment:, recipient: notification.recipient }
    end

    notification_methods do
      delegate :comment, :commentable, :commenter_name, :title, :body, :email_params, to: :event

      def recipient_allows_comment_notifications?
        !recipient.respond_to?(:notification_preferences) ||
          recipient.notification_preferences.fetch('notify_on_comments', true)
      end
    end

    def comment_url
      return unless commentable&.persisted?

      BetterTogether::Engine.routes.url_helpers.polymorphic_url(
        commentable,
        anchor: comment.anchor_id,
        locale:
      )
    end
  end
end
