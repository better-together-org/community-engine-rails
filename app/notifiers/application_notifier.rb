# frozen_string_literal: true

class ApplicationNotifier < Noticed::Event # rubocop:todo Style/Documentation
  def deliver_now(recipient)
    deliver(recipient)
  end

  def locale
    I18n.locale || I18n.default_locale
  end

  def locale_for_notification(notification)
    notification&.recipient&.locale || locale
  end

  notification_methods do
    def recipient_has_email?
      recipient.respond_to?(:email) && recipient.email.present? &&
        (!recipient.respond_to?(:notification_preferences) ||
         recipient.notification_preferences.fetch('notify_by_email', true))
    end
  end
end
