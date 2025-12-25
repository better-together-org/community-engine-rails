# frozen_string_literal: true

module BetterTogether
  # Notifies a person when their membership is updated (role change, status change, etc.)
  class MembershipUpdatedNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications
    deliver_by :email, mailer: 'BetterTogether::MembershipMailer', method: :updated, params: :email_params,
                       queue: :mailers do |config|
      config.if = -> { recipient_has_email? }
    end

    required_param :membership, :old_role, :new_role

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

    def old_role
      params[:old_role]
    end

    def new_role
      params[:new_role]
    end

    def locale
      member&.locale || I18n.locale || I18n.default_locale
    end

    def title
      I18n.with_locale(locale) do
        I18n.t('better_together.notifications.membership_updated.title',
               joinable_name: joinable_name,
               old_role_name: old_role_name,
               new_role_name: new_role_name,
               default: 'Membership updated: %<old_role_name>s → %<new_role_name>s in %<joinable_name>s')
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t('better_together.notifications.membership_updated.body',
               joinable_name: joinable_name,
               old_role_name: old_role_name,
               new_role_name: new_role_name,
               default: 'Your role has been changed from %<old_role_name>s to %<new_role_name>s in %<joinable_name>s')
      end
    end

    def build_message(_notification)
      { title:, body:, url: url }
    end

    def email_params(_notification)
      { membership:, recipient: member, old_role:, new_role: }
    end

    notification_methods do
      delegate :membership, :member, :joinable, :old_role, :new_role, :title, :body, :url, to: :event

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

    def old_role_name
      old_role&.name || I18n.t('better_together.notifications.membership_updated.unknown_role', default: 'unknown')
    end

    def new_role_name
      new_role&.name || I18n.t('better_together.notifications.membership_updated.unknown_role', default: 'unknown')
    end
  end
end
