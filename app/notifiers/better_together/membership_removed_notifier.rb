# frozen_string_literal: true

module BetterTogether
  # Notifies a person when their membership is removed/destroyed
  class MembershipRemovedNotifier < ApplicationNotifier
    deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                              queue: :notifications
    deliver_by :email, mailer: 'BetterTogether::MembershipMailer', method: :removed, params: :email_params,
                       queue: :mailers do |config|
      config.if = -> { recipient_has_email? }
    end

    required_param :member_data

    def member_data
      params[:member_data]
    end

    def member_email
      member_data[:email]
    end

    def member_name
      member_data[:name]
    end

    def joinable_name
      member_data[:joinable_name]
    end

    def role_name
      member_data[:role_name]
    end

    def locale
      member_data[:locale] || I18n.locale || I18n.default_locale
    end

    def title
      I18n.with_locale(locale) do
        I18n.t('better_together.notifications.membership_removed.title',
               joinable_name: joinable_name,
               role_name: role_name,
               default: 'Membership removed: %<role_name>s in %<joinable_name>s')
      end
    end

    def body
      I18n.with_locale(locale) do
        I18n.t('better_together.notifications.membership_removed.body',
               joinable_name: joinable_name,
               role_name: role_name,
               default: 'Your %<role_name>s membership in %<joinable_name>s has been removed')
      end
    end

    def build_message(_notification)
      { title:, body:, url: url }
    end

    def email_params(_notification)
      { member_data:, recipient: { email: member_email, name: member_name, locale: } }
    end

    notification_methods do
      delegate :member_data, :member_email, :member_name, :joinable_name, :role_name, :title, :body, :url, to: :event

      def recipient_has_email?
        member_email.present?
      end
    end

    def url
      return unless record

      BetterTogether::Engine.routes.url_helpers.polymorphic_path(record, locale:)
    end
  end
end
