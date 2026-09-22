# frozen_string_literal: true

class ApplicationNotifier < Noticed::Event # rubocop:todo Style/Documentation
  def deliver_now(recipient)
    deliver(recipient)
  end

  # Noticed::Deliverable#deliver bulk-inserts Notification rows via
  # notifications.insert_all!, which never runs ActiveRecord callbacks -
  # Noticed::Notification's before_create :stamp_platform_id (see
  # config/initializers/noticed_platform_scope.rb) can never fire for a
  # notification created through the normal delivery path. This is the actual
  # write path, so platform_id has to be set here, in the attributes hash
  # insert_all! writes directly.
  def recipient_attributes_for(recipient)
    super.merge(platform_id: resolved_platform_id)
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

  private

  def resolved_platform_id
    Current.platform&.id ||
      (record.platform_id if record.respond_to?(:platform_id)) ||
      BetterTogether::Platform.find_by(host: true)&.id
  end
end
