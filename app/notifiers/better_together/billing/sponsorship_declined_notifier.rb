# frozen_string_literal: true

module BetterTogether
  module Billing
    # Notifies the sponsor (or a community sponsor's managers) that their
    # sponsorship offer was declined.
    class SponsorshipDeclinedNotifier < SponsorshipNotifierBase
      deliver_by :email, mailer: 'BetterTogether::Billing::SponsorshipMailer', method: :declined,
                         params: :email_params, queue: :mailers do |config|
        config.if = -> { recipient_has_email? }
      end

      def title_i18n_key
        'better_together.notifications.sponsorship_declined.title'
      end

      def body_i18n_key
        'better_together.notifications.sponsorship_declined.body'
      end

      def default_title
        '%<beneficiary_name>s declined your sponsorship offer'
      end

      def default_body
        '%<beneficiary_name>s declined your offer to sponsor them.'
      end
    end
  end
end
