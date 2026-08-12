# frozen_string_literal: true

module BetterTogether
  module Billing
    # Notifies the beneficiary (or a community beneficiary's managers) that a
    # sponsor has offered to fund them — requires beneficiary acceptance
    # before any Stripe checkout happens.
    class SponsorshipOfferedNotifier < SponsorshipNotifierBase
      deliver_by :email, mailer: 'BetterTogether::Billing::SponsorshipMailer', method: :offered,
                         params: :email_params, queue: :mailers do |config|
        config.if = -> { recipient_has_email? }
      end

      def title_i18n_key
        'better_together.notifications.sponsorship_offered.title'
      end

      def body_i18n_key
        'better_together.notifications.sponsorship_offered.body'
      end

      def default_title
        '%<sponsor_name>s has offered to sponsor you'
      end

      def default_body
        '%<sponsor_name>s would like to fund your hosted-access balance. Review and respond to this offer.'
      end
    end
  end
end
