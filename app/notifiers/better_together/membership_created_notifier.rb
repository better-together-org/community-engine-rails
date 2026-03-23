# frozen_string_literal: true

module BetterTogether
  # Notifies a person when a membership is created for them
  class MembershipCreatedNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications
    deliver_by :email, mailer: 'BetterTogether::MembershipMailer', method: :created, params: :email_params,
                       queue: :mailers do |config|
      config.if = -> { recipient_has_email? }
    end

    required_param :membership

    validates :record, presence: true

    def membership
      params[:membership] || record
    end

    def member
      membership&.member
    end

    def joinable
      membership&.joinable
    end

    def role
      membership&.role
    end

    def locale
      member&.locale || I18n.locale || I18n.default_locale
    end

    def title
      I18n.with_locale(locale) do
        I18n.t('better_together.notifications.membership_created.title',
               joinable_name: joinable_name,
               role_name: role_name,
               default: 'New membership: %<role_name>s in %<joinable_name>s')
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t('better_together.notifications.membership_created.body',
               joinable_name: joinable_name,
               role_name: role_name,
               default: 'You have been added as %<role_name>s in %<joinable_name>s')
      end
    end

    def build_message(_notification)
      { title:, body:, url: url }
    end

    def email_params(_notification)
      { membership:, recipient: member }
    end

    notification_methods do
      delegate :membership, :member, :joinable, :role, :title, :body, :url, to: :event

      def recipient_has_email?
        recipient.respond_to?(:email) && recipient.email.present? &&
          (!recipient.respond_to?(:notification_preferences) ||
           recipient.notification_preferences.fetch('notify_by_email', true))
      end
    end

    def url
      return unless joinable

      BetterTogether::Engine.routes.url_helpers.polymorphic_path(joinable, locale:)
    end

    private

    def joinable_name
      joinable.respond_to?(:name) ? joinable.name : joinable.to_s
    end

    def role_name
      role&.name || I18n.t('better_together.notifications.membership_created.default_role_name', default: 'member')
    end
  end
end
