# frozen_string_literal: true

module BetterTogether
  module Billing
    # Sends the hosted-access grace-period email to a community's managers.
    class HostedAccessMailer < ApplicationMailer
      def grace_notice
        setup_context
        return if invalid_recipient?

        mail(to: @recipient.email, subject: I18n.t(
          'better_together.billing.hosted_access_mailer.grace_notice.subject',
          community_name: @community_name,
          default: "Billing needs attention for #{@community_name}"
        ))
      end

      private

      def setup_context
        @subscription = params[:subscription]
        @community = @subscription&.beneficiary
        @community_name = @community&.name
        @recipient = params[:recipient]
        @billing_url = params[:billing_url]
        @grace_period_ends_on = @subscription&.grace_period_expires_at&.to_date
        self.locale = recipient_locale
      end

      def recipient_locale
        @recipient&.locale || I18n.locale || I18n.default_locale
      end

      def invalid_recipient?
        @recipient.blank? || @recipient.email.blank?
      end
    end
  end
end
