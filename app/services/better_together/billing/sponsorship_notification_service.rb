# frozen_string_literal: true

module BetterTogether
  module Billing
    # Resolves notification recipients for a Sponsorship and delivers the
    # offered/accepted/declined/ended notifications. A sponsor or beneficiary
    # may be a Person (notify directly) or a Community (notify its managers) —
    # mirrors MembershipRequestNotificationService's reviewer-resolution
    # pattern rather than assuming a single-person recipient.
    class SponsorshipNotificationService
      COMMUNITY_MANAGER_ROLES = %w[community_manager community_administrator].freeze

      def initialize(sponsorship)
        @sponsorship = sponsorship
      end

      def notify_offered
        deliver(BetterTogether::Billing::SponsorshipOfferedNotifier, beneficiary_recipients)
      end

      def notify_accepted
        deliver(BetterTogether::Billing::SponsorshipAcceptedNotifier, sponsor_recipients)
      end

      def notify_declined
        deliver(BetterTogether::Billing::SponsorshipDeclinedNotifier, sponsor_recipients)
      end

      def notify_ended
        deliver(BetterTogether::Billing::SponsorshipEndedNotifier, other_party_recipients)
      end

      private

      attr_reader :sponsorship

      def deliver(notifier_class, recipients)
        recipients.each do |recipient|
          notifier_class.with(sponsorship:).deliver_later(recipient)
        end
      end

      def sponsor_recipients
        recipients_for(sponsorship.sponsor)
      end

      def beneficiary_recipients
        recipients_for(sponsorship.beneficiary)
      end

      # #end! can be called by either party — notify whichever side isn't the
      # one who (presumably) just called it. Notifying both sides is simpler
      # and safer than tracking who initiated the call, since ending a
      # sponsorship someone is receiving/giving is always worth knowing about.
      def other_party_recipients
        (sponsor_recipients + beneficiary_recipients).uniq(&:id)
      end

      def recipients_for(entity)
        return [] if entity.blank?
        return [entity] if entity.is_a?(BetterTogether::Person)
        return community_managers(entity) if entity.is_a?(BetterTogether::Community)

        []
      end

      def community_managers(community)
        BetterTogether::PersonCommunityMembership
          .joins(:role)
          .includes(:member)
          .active
          .where(joinable: community)
          .where(better_together_roles: { identifier: COMMUNITY_MANAGER_ROLES })
          .map(&:member)
          .compact
      end
    end
  end
end
