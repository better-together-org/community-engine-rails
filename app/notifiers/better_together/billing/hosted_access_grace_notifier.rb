# frozen_string_literal: true

module BetterTogether
  module Billing
    # Notifies a community's managers that its hosted-access billing has
    # lapsed and the app-owned grace period (Subscription#grace_period)
    # will expire soon — the only notifier in this family, since this is a
    # one-directional informational notice, not an offer/accept/decline
    # exchange like Billing::Sponsorship's notifiers.
    class HostedAccessGraceNotifier < ApplicationNotifier
      deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                                queue: :notifications
      deliver_by :email, mailer: 'BetterTogether::Billing::HostedAccessMailer', method: :grace_notice,
                         params: :email_params, queue: :mailers do |config|
        config.if = -> { recipient_has_email? }
      end

      required_param :subscription

      def subscription = params[:subscription]
      def community = subscription&.beneficiary

      def locale
        I18n.locale || I18n.default_locale
      end

      def build_message(_notification)
        { title:, body:, url: billing_url }
      end

      def email_params(notification)
        { subscription:, recipient: notification.recipient, billing_url: }
      end

      def billing_url
        return if community.blank?

        BetterTogether::Engine.routes.url_helpers.community_billing_url(community, locale:)
      end

      def title
        I18n.with_locale(locale) do
          I18n.t(
            'better_together.notifications.hosted_access_grace.title',
            community_name:,
            default: default_title
          )
        end
      end

      def body
        I18n.with_locale(locale) do
          I18n.t(
            'better_together.notifications.hosted_access_grace.body',
            community_name:,
            grace_period_ends_on:,
            default: default_body
          )
        end
      end

      def community_name
        community&.name
      end

      def grace_period_ends_on
        expires_at = subscription&.grace_period_expires_at
        return if expires_at.blank?

        expires_at.to_date.to_s
      end

      def default_title
        "Billing needs attention for #{community_name}"
      end

      def default_body
        "Hosted access for #{community_name} will pause on #{grace_period_ends_on} unless billing is resolved."
      end
    end
  end
end
