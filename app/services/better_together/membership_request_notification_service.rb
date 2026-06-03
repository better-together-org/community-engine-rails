# frozen_string_literal: true

module BetterTogether
  # Handles reviewer and requester notifications for membership requests.
  class MembershipRequestNotificationService # rubocop:todo Metrics/ClassLength
    COMMUNITY_REVIEWER_ROLES = %w[community_manager community_administrator].freeze
    PLATFORM_REVIEWER_ROLES = %w[platform_manager platform_administrator].freeze

    def initialize(membership_request)
      @membership_request = membership_request
    end

    def notify_submission
      reviewer_recipients.each do |reviewer|
        BetterTogether::MembershipRequestSubmittedNotifier.with(
          record: @membership_request,
          membership_request: @membership_request
        ).deliver_later(reviewer)
      end
    end

    def notify_approval(approval_invitation: nil)
      if @membership_request.unauthenticated?
        send_community_invitation_email(approval_invitation)
        return
      end

      # Authenticated approvals create an active membership, and the membership model
      # already emits the canonical in-app/email confirmation.
      nil
    end

    def notify_decline(decision_actor: nil)
      return notify_authenticated_decline(decision_actor) if @membership_request.creator.present?
      return if requestor_email.blank?

      notify_email_only_decline
    end

    private

    def reviewer_recipients
      (community_reviewers + platform_reviewers)
        .compact
        .uniq(&:id)
        .reject { |person| requester_person.present? && person.id == requester_person.id }
    end

    def community_reviewers
      return [] unless community

      BetterTogether::PersonCommunityMembership
        .joins(:role)
        .includes(:member)
        .active
        .where(joinable: community)
        .where(better_together_roles: { identifier: COMMUNITY_REVIEWER_ROLES })
        .map(&:member)
    end

    def platform_reviewers
      return [] unless platform

      BetterTogether::PersonPlatformMembership
        .joins(:role)
        .includes(:member)
        .active
        .where(joinable: platform)
        .where(better_together_roles: { identifier: PLATFORM_REVIEWER_ROLES })
        .map(&:member)
    end

    def send_community_invitation_email(approval_invitation)
      invitation = approval_invitation || BetterTogether::CommunityInvitation.find_by(
        invitable: community,
        invitee_email: requestor_email
      )
      return unless invitation&.invitee_email.present?

      BetterTogether::CommunityInvitationsMailer.with(
        invitation:,
        invitable: invitation.invitable
      ).invite.deliver_later
    end

    def notify_authenticated_decline(decision_actor)
      requester = @membership_request.creator

      BetterTogether::MembershipRequestDeclinedNotifier.with(
        record: @membership_request,
        membership_request: @membership_request,
        decision_actor:
      ).deliver_later(requester)

      return unless requester.email.present?

      BetterTogether::MembershipRequestMailer.with(
        membership_request: @membership_request,
        recipient: requester,
        review_url: request_review_url,
        decision_actor:
      ).declined.deliver_later
    end

    def notify_email_only_decline
      BetterTogether::MembershipRequestMailer.with(
        membership_request: @membership_request,
        recipient: requestor_contact,
        review_url: community_url
      ).declined.deliver_later
    end

    def requestor_contact
      {
        email: requestor_email,
        locale: I18n.locale,
        time_zone: Time.zone.to_s,
        name: requestor_name
      }
    end

    def community
      @membership_request.target if @membership_request.target.is_a?(BetterTogether::Community)
    end

    def platform
      community&.primary_platform
    end

    def requester_person
      @membership_request.creator
    end

    def requestor_email
      @membership_request.requestor_email.presence || requester_person&.email
    end

    def requestor_name
      @membership_request.requestor_name.presence || requester_person&.name || requestor_email
    end

    def community_url
      return unless community&.persisted?

      BetterTogether::Engine.routes.url_helpers.community_url(community, locale: I18n.locale)
    end

    def request_review_url
      return unless community&.persisted? && @membership_request.persisted?

      BetterTogether::Engine.routes.url_helpers.community_membership_request_url(
        community,
        @membership_request,
        locale: I18n.locale
      )
    end
  end
end
