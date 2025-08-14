# frozen_string_literal: true

module BetterTogether
  # Notifies a person when added to or removed from a Page as an author
  class PageAuthorshipNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message

    deliver_by :email,
               mailer: 'BetterTogether::AuthorshipMailer',
               method: :authorship_changed_notification,
               params: :email_params do |config|
      config.wait = 15.minutes
      config.if = -> { send_email_notification? }
    end

    validates :record, presence: true

    # record is the Page; keep naming helpers similar to NewMessageNotifier
    def page
      record
    end

    def action
      params[:action]
    end

    def actor_id
      params[:actor_id]
    end

    def actor_name
      params[:actor_name]
    end

    def actor
      @actor ||= BetterTogether::Person.find_by(id: actor_id)
    end

    notification_methods do
      delegate :page, to: :event
      delegate :url, to: :event
      delegate :identifier, to: :event
      delegate :action, to: :event
      delegate :actor, to: :event
      delegate :actor_name, to: :event

      def send_email_notification?
        recipient.email.present? && recipient.notify_by_email && should_send_email?
      end

      def should_send_email?
        # Mirror conversation notifier grouping by related record (page)
        unread_notifications = recipient.notifications.where(
          event_id: BetterTogether::PageAuthorshipNotifier.where(params: { page_id: page.id }).select(:id),
          read_at: nil
        ).order(created_at: :desc)

        if unread_notifications.none?
          false
        else
          # Only send one email per unread notifications per page
          page.id == unread_notifications.last.event.record_id
        end
      end
    end

    def identifier
      page.id
    end

    def url
      page.url
    end

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    def title # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      name = actor_name || actor&.name
      if action == 'removed'
        if name.present?
          I18n.t('better_together.page_authorship_notifier.removed_by', page_title: page.title, actor_name: name)
        else
          I18n.t('better_together.page_authorship_notifier.removed', page_title: page.title)
        end
      elsif name.present?
        I18n.t('better_together.page_authorship_notifier.added_by', page_title: page.title, actor_name: name)
      else
        I18n.t('better_together.page_authorship_notifier.added', page_title: page.title)
      end
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    def body
      # Keep body concise; UI partial will display details
      title
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
      { page: notification.record, action: action, actor_id:, actor_name: }
    end
  end
end
