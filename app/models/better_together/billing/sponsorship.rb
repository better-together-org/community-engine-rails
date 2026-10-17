# frozen_string_literal: true

module BetterTogether
  module Billing
    # The standing consent relationship authorizing a sponsor to fund a
    # beneficiary. Deliberately has no pointer to a specific billing record —
    # it authorizes an ongoing funding relationship, not ownership of one.
    # Concrete acts of sponsoring (Stripe balance top-ups, future non-monetary
    # benefit-credit grants) are separate records linked back to this one.
    class Sponsorship < ApplicationRecord
      self.table_name = 'better_together_billing_sponsorships'

      STATUS_VALUES = {
        pending: 'pending',
        accepted: 'accepted',
        declined: 'declined',
        active: 'active',
        ended: 'ended'
      }.freeze

      has_secure_token :token

      belongs_to :sponsor, polymorphic: true
      belongs_to :beneficiary, polymorphic: true

      has_many :monetary_contributions,
               class_name: 'BetterTogether::Billing::MonetaryContribution',
               dependent: :restrict_with_error,
               inverse_of: :sponsorship

      has_many :benefit_credits,
               class_name: 'BetterTogether::Billing::BenefitCredit',
               dependent: :restrict_with_error,
               inverse_of: :sponsorship

      enum :status, STATUS_VALUES, prefix: :status

      validates :sponsor_type, inclusion: { in: -> { BetterTogether::Billing::Billable.included_in_models.map(&:name) } }
      validates :beneficiary_type,
                inclusion: { in: -> { BetterTogether::Billing::SponsorshipRecipient.included_in_models.map(&:name) } }
      validate :beneficiary_currently_accepts_sponsorship, on: :create, if: :consent_enforced?

      scope :for_beneficiary, ->(record) { where(beneficiary: record) }
      scope :for_sponsor, ->(record) { where(sponsor: record) }

      def self.consent_enforced?
        ActiveModel::Type::Boolean.new.cast(ENV.fetch('BT_BILLING_SPONSORSHIP_CONSENT_ENFORCED', 'true'))
      end

      def accept!
        update!(status: 'accepted', accepted_at: Time.current)
        notification_service.notify_accepted
      end

      def decline!(reason: nil)
        update!(status: 'declined', declined_at: Time.current, cancellation_reason: reason)
        notification_service.notify_declined
      end

      def activate!
        update!(status: 'active')
      end

      # Real "unsponsor" action. Ending a Sponsorship only stops future
      # contributions under it — it never needs to touch a subscription,
      # because the beneficiary's own subscription is never owned by the
      # sponsor under this design.
      def end!(reason: nil)
        update!(status: 'ended', ended_at: Time.current, cancellation_reason: reason)
        notification_service.notify_ended
      end

      def notification_service
        BetterTogether::Billing::SponsorshipNotificationService.new(self)
      end

      private

      def consent_enforced?
        self.class.consent_enforced?
      end

      def beneficiary_currently_accepts_sponsorship
        return if beneficiary.blank?
        return if beneficiary.respond_to?(:accepts_sponsorship?) && beneficiary.accepts_sponsorship?

        errors.add(:beneficiary, :sponsorship_not_accepted)
      end
    end
  end
end
