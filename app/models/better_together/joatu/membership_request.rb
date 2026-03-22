# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Represents a public request to join a Community.
    #
    # Two paths depending on whether the requester has an account:
    #
    # 1. Unauthenticated visitor (creator nil):
    #    after_agreement_acceptance! → CommunityInvitation(invitee_email:)
    #    → visitor registers → CommunityInvitation#after_accept! → PersonCommunityMembership
    #
    # 2. Logged-in person (creator present, requesting another community):
    #    after_agreement_acceptance! → PersonCommunityMembership.find_or_create_by!
    class MembershipRequest < Request
      CATEGORY_NAME = 'Membership Requests'

      # Minimal stand-in for an Offer used during approval when no real offer exists.
      # Provides just enough interface for after_agreement_acceptance! (needs #creator).
      ApprovalOffer = Struct.new(:creator)

      before_validation :assign_membership_request_category
      before_validation :generate_name_from_requestor

      validates :target_type, inclusion: { in: ['BetterTogether::Community'] }
      validate :target_community_must_exist

      # requestor_email is required for unauthenticated submissions (no creator)
      validates :requestor_email,
                presence: true,
                format: { with: URI::MailTo::EMAIL_REGEXP },
                if: :unauthenticated?

      # Exchange concern adds validates :creator, presence: true.
      # MembershipRequest allows nil creator for public (unauthenticated) requests.
      # We post-process errors to remove the inherited creator error in that case.
      validate :allow_nil_creator_for_unauthenticated

      def after_agreement_acceptance!(offer:)
        if unauthenticated?
          create_community_invitation!(offer)
        else
          create_community_membership!
        end
      end

      # Approve the request.  Triggers the appropriate downstream action depending on
      # whether the requester has an account (create membership directly) or not
      # (send them a CommunityInvitation so they can register and join).
      #
      # @param approver [BetterTogether::Person] the person performing the approval
      # @raise [ActiveRecord::RecordInvalid] if the request cannot be saved
      def approve!(approver: nil)
        # Build a minimal stub so after_agreement_acceptance! has something to work with
        # when it needs the approver (used as invitation sender for unauthenticated path).
        stub_offer = ApprovalOffer.new(creator: approver)

        ::ActiveRecord::Base.transaction do
          after_agreement_acceptance!(offer: stub_offer)
          update!(status: 'fulfilled')
        end
      end

      # Decline the request.
      #
      # @raise [ActiveRecord::RecordInvalid] if the status update fails
      def decline!
        update!(status: 'closed')
      end

      # True when the request was submitted without an account (public form)
      def unauthenticated?
        creator_id.nil?
      end

      private

      def allow_nil_creator_for_unauthenticated
        errors.delete(:creator) if unauthenticated?
      end

      # Find (or lazily create) the canonical Membership Requests category.
      # CategoryBuilder seeds it; this fallback avoids hard failures in test/dev
      # environments where seeds may not have been run.
      def generate_name_from_requestor
        return if name.present?

        # Use requestor_name for unauthenticated; fall back to creator's name for
        # authenticated submissions where requestor_name may not be supplied.
        display_name = requestor_name.presence || creator&.name.presence || requestor_email
        self.name = I18n.t(
          'better_together.membership_requests.name',
          requestor: display_name,
          default: "Membership request from #{display_name}"
        )
      end

      def assign_membership_request_category
        return if categories.map(&:identifier).include?(CATEGORY_NAME.parameterize)

        category = ::BetterTogether::Joatu::Category
                   .find_by(identifier: CATEGORY_NAME.parameterize)
                   .presence ||
                   ::BetterTogether::Joatu::Category.create!(name: CATEGORY_NAME)
        categories << category
      end

      def target_community_must_exist
        return if target.is_a?(::BetterTogether::Community)

        errors.add(:target, 'must be a community')
      end

      def default_community_role
        ::BetterTogether::Role.find_by(identifier: 'community_member')
      end

      def create_community_invitation!(offer)
        approving_person = offer&.creator
        locale = I18n.locale.to_s

        ::BetterTogether::CommunityInvitation.find_or_create_by!(
          invitable: target,
          invitee_email: requestor_email
        ) do |invitation|
          invitation.inviter = approving_person
          invitation.role = default_community_role
          invitation.locale = locale
          invitation.status = 'pending'
          invitation.valid_from = Time.current
        end
      end

      def create_community_membership!
        target.person_community_memberships.find_or_create_by!(
          member: creator,
          role: default_community_role
        ) do |membership|
          membership.status = 'active'
        end
      end
    end
  end
end
