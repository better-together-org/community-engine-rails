# frozen_string_literal: true

module BetterTogether
  # Access control for calendars
  class EventPolicy < PlatformRecordPolicy
    include SelfServicePublishablePolicy

    def index?
      true
    end

    def show?
      (public_or_member_scoped_community?(record) && record.starts_at.present?) ||
        creator_or_platform_steward ||
        event_host_member? ||
        invitation? ||
        valid_invitation_token?
    end

    def ics?
      record.starts_at.present? && show?
    end

    def new?
      create?
    end

    def update?
      creator_or_platform_steward || event_host_member?
    end

    def create?
      return false unless user.present?

      platform_manager? || community_event_manager? || self_service_event_creator?
    end

    def available_hosts?
      # Users who can create or edit events can view available hosts
      user.present? && (platform_manager? || agent.valid_event_host_ids.any?)
    end

    def destroy?
      creator_or_platform_steward || event_host_member?
    end

    # RSVP policy methods
    def rsvp_interested?
      show? && user.present?
    end

    def rsvp_going?
      show? && user.present?
    end

    def rsvp_cancel?
      show? && user.present?
    end

    def event_host_member?
      return false unless user.present?

      can_represent_host = user.present? && record.event_hosts.any? && agent.valid_event_host_ids.any?

      # .map (not .pluck) — pluck always hits the DB directly, which returns
      # empty for a new/unsaved record's in-memory .build'd event_hosts
      # (e.g. during authorization on the `new`/`create` actions, before the
      # event is persisted).
      has_common_hosts = record.event_hosts.map(&:host_id).intersect?(agent.valid_event_host_ids)
      can_represent_host && has_common_hosts
    end

    # Self-serve event creation: any person who could represent one of the
    # submitted event_hosts (via community membership), gated by having
    # accepted the content publishing agreement. Deliberately bespoke rather
    # than the shared module's #self_service_content_creator?, since Event
    # has no direct :community association and event_host_member? already
    # correctly resolves host-standing against the submitted event_hosts.
    def self_service_event_creator?
      event_host_member? && accepted_content_publishing_agreement?
    end

    def community_event_manager?
      return false unless user.present?

      community_host_ids = record.event_hosts
                                 .select { |h| h.host_type == 'BetterTogether::Community' }
                                 .map(&:host_id)
      return false if community_host_ids.empty?

      community_host_ids.any? do |community_id|
        community = BetterTogether::Community.find_by(id: community_id)
        next false unless community

        permitted_to?('manage_community_events', community)
      end
    end

    # Filtering and sorting for calendars according to permissions and context
    class Scope < PlatformRecordPolicy::Scope
      def resolve
        platform_scoped.with_attached_cover_image
                       .includes(:string_translations, :location, :event_hosts, categorizations: {
                                   category: %i[
                                     string_translations cover_image_attachment cover_image_blob
                                   ]
                                 }).order(
                                   starts_at: :desc, created_at: :desc
                                 ).where(permitted_query)
      end

      protected

      # rubocop:todo Metrics/MethodLength
      def permitted_query # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        events_table = ::BetterTogether::Event.arel_table
        event_hosts_table = ::BetterTogether::EventHost.arel_table

        query = visible_privacy_query(events_table)

        if platform_event_manager?
          query = query.or(events_table[:privacy].eq('private'))
        else
          # Draft events are only visible to people connected to them
          # (creator, hosts, attendees, invitees) or platform event managers.
          query = query.and(events_table[:status].not_eq('draft'))

          if agent
            query = query.or(
              events_table[:creator_id].eq(agent.id)
            )

            if agent.valid_event_host_ids.any?
              event_ids = event_hosts_table
                          .where(event_hosts_table[:host_id].in(agent.valid_event_host_ids))
                          .project(:event_id)
              query = query.or(
                events_table[:id].in(event_ids)
              )
            end

            if agent.event_attendances.any?
              event_ids = agent.event_attendances.pluck(:event_id)
              query = query.or(
                events_table[:id].in(event_ids)
              )
            end

            if agent.event_invitations.any?
              event_ids = agent.event_invitations.pluck(:invitable_id)
              query = query.or(
                events_table[:id].in(event_ids)
              )
            end
          else
            # Events must have a start time to be shown to people who aren't connected to the event
            query = query.and(events_table[:starts_at].not_eq(nil))
          end
        end

        # Add logic for invitation token access
        if invitation_token.present?
          invitation_table = ::BetterTogether::EventInvitation.arel_table
          event_ids_with_valid_invitations = invitation_table
                                             .where(invitation_table[:token].eq(invitation_token))
                                             .where(invitation_table[:status].eq('pending'))
                                             .project(:invitable_id)

          query = query.or(events_table[:id].in(event_ids_with_valid_invitations))
        end

        query
      end
      # rubocop:enable Metrics/MethodLength

      private

      def platform_event_manager?
        permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
      end
    end

    def creator_or_platform_steward
      user.present? && (creator_of?(record) || platform_manager?)
    end

    def invitation?
      return false unless agent.present?

      # Check if the current person has an invitation to this event
      BetterTogether::EventInvitation.exists?(
        invitable: record,
        invitee: agent
      )
    end

    # Check if there's a valid invitation token for this event
    def valid_invitation_token?
      return false unless invitation_token.present?

      invitation = BetterTogether::EventInvitation.find_by(
        token: invitation_token,
        invitable: record
      )

      invitation.present? && invitation.status_pending?
    end
  end
end
