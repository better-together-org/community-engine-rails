# frozen_string_literal: true

module BetterTogether
  module Billing
    # Base class for sponsorship notifiers — shared message/email plumbing
    # for the offered/accepted/declined/ended notifications. Mirrors
    # InvitationNotifierBase's shape; simpler since Sponsorship has no STI
    # per-type subclassing to resolve.
    class SponsorshipNotifierBase < ApplicationNotifier
      deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                                queue: :notifications

      required_param :sponsorship

      def sponsorship = params[:sponsorship]

      def build_message(_notification)
        { title:, body:, url: review_url }
      end

      def email_params(notification)
        { sponsorship:, recipient: notification.recipient, review_url: }
      end

      def review_url
        return unless sponsorship&.persisted?

        BetterTogether::Engine.routes.url_helpers.sponsorship_url(sponsorship.token, locale:)
      end

      def sponsor_name
        sponsorship&.sponsor&.name
      end

      def beneficiary_name
        sponsorship&.beneficiary&.name
      end

      # Template methods — implemented by subclasses

      def title_i18n_key
        raise NotImplementedError, "#{self.class} must implement #title_i18n_key"
      end

      def body_i18n_key
        raise NotImplementedError, "#{self.class} must implement #body_i18n_key"
      end

      def title
        I18n.with_locale(locale) { I18n.t(title_i18n_key, **title_i18n_vars, default: default_title) }
      end

      def body
        I18n.with_locale(locale) { I18n.t(body_i18n_key, **body_i18n_vars, default: default_body) }
      end

      def title_i18n_vars
        { sponsor_name:, beneficiary_name: }
      end

      def body_i18n_vars
        { sponsor_name:, beneficiary_name: }
      end

      def default_title
        raise NotImplementedError, "#{self.class} must implement #default_title"
      end

      def default_body
        raise NotImplementedError, "#{self.class} must implement #default_body"
      end
    end
  end
end
