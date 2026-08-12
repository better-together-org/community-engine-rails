# frozen_string_literal: true

module BetterTogether
  module Billing
    # Notifies both sides of a Sponsorship that it has ended. Sent to both
    # sponsor and beneficiary regardless of who called #end! — see
    # SponsorshipNotificationService#other_party_recipients.
    class SponsorshipEndedNotifier < SponsorshipNotifierBase
      deliver_by :email, mailer: 'BetterTogether::Billing::SponsorshipMailer', method: :ended,
                         params: :email_params, queue: :mailers do |config|
        config.if = -> { recipient_has_email? }
      end

      def title_i18n_key
        'better_together.notifications.sponsorship_ended.title'
      end

      def body_i18n_key
        'better_together.notifications.sponsorship_ended.body'
      end

      def default_title
        'A sponsorship between %<sponsor_name>s and %<beneficiary_name>s has ended'
      end

      def default_body
        'The sponsorship between %<sponsor_name>s and %<beneficiary_name>s is no longer active.'
      end
    end
  end
end
