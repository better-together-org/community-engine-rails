# frozen_string_literal: true

module BetterTogether
  module Billing
    # Notifies the sponsor (or a community sponsor's managers) that their
    # sponsorship offer was accepted.
    class SponsorshipAcceptedNotifier < SponsorshipNotifierBase
      deliver_by :email, mailer: 'BetterTogether::Billing::SponsorshipMailer', method: :accepted,
                         params: :email_params, queue: :mailers do |config|
        config.if = -> { recipient_has_email? }
      end

      def title_i18n_key
        'better_together.notifications.sponsorship_accepted.title'
      end

      def body_i18n_key
        'better_together.notifications.sponsorship_accepted.body'
      end

      def default_title
        '%<beneficiary_name>s accepted your sponsorship offer'
      end

      def default_body
        '%<beneficiary_name>s accepted your offer to sponsor them. You can now contribute to their balance.'
      end
    end
  end
end
