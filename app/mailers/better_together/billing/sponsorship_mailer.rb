# frozen_string_literal: true

module BetterTogether
  module Billing
    # Sends sponsor/beneficiary emails for sponsorship offer/accept/decline/end
    # events. Mirrors MembershipRequestMailer's shape — recipients are always
    # resolved to real Person records with an email before this mailer is
    # invoked (see SponsorshipNotificationService), so there's no email-only/
    # STI complexity to handle here.
    class SponsorshipMailer < ApplicationMailer
      def offered
        setup_context
        return if invalid_recipient?

        mail(to: @recipient.email, subject: I18n.t(
          'better_together.billing.sponsorship_mailer.offered.subject',
          sponsor_name: @sponsor_name,
          default: "#{@sponsor_name} has offered to sponsor you"
        ))
      end

      def accepted
        setup_context
        return if invalid_recipient?

        mail(to: @recipient.email, subject: I18n.t(
          'better_together.billing.sponsorship_mailer.accepted.subject',
          beneficiary_name: @beneficiary_name,
          default: "#{@beneficiary_name} accepted your sponsorship offer"
        ))
      end

      def declined
        setup_context
        return if invalid_recipient?

        mail(to: @recipient.email, subject: I18n.t(
          'better_together.billing.sponsorship_mailer.declined.subject',
          beneficiary_name: @beneficiary_name,
          default: "#{@beneficiary_name} declined your sponsorship offer"
        ))
      end

      def ended
        setup_context
        return if invalid_recipient?

        mail(to: @recipient.email, subject: I18n.t(
          'better_together.billing.sponsorship_mailer.ended.subject',
          sponsor_name: @sponsor_name,
          beneficiary_name: @beneficiary_name,
          default: "The sponsorship between #{@sponsor_name} and #{@beneficiary_name} has ended"
        ))
      end

      private

      def setup_context
        @sponsorship = params[:sponsorship]
        @recipient = params[:recipient]
        @sponsor_name = @sponsorship&.sponsor&.name
        @beneficiary_name = @sponsorship&.beneficiary&.name
        @review_url = params[:review_url]
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
