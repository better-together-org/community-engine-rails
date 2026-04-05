# frozen_string_literal: true

module BetterTogether
  # Access control for calendars
  class EventPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      (public_or_signed_in_community?(record) && record.starts_at.present?) ||
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
      platform_event_manager? || event_host_member?
    end

    def available_hosts?
      # Users who can create or edit events can view available hosts
      user.present? && (platform_event_manager? || agent.valid_event_host_ids.any?)
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

      has_common_hosts = record.event_hosts.pluck(:host_id).intersect?(agent.valid_event_host_ids)
      can_represent_host && has_common_hosts
    end

    # Filtering and sorting for calendars according to permissions and context
    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.with_attached_cover_image
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

        query = if agent.present?
                  events_table[:privacy].in(%w[public community])
                else
                  events_table[:privacy].eq('public')
                end

        if platform_event_manager?
          query = query.or(events_table[:privacy].eq('private'))
        elsif agent
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

          query
        else
          # Events must have a start time to be shown to people who aren't connected to the event
          query = query.and(events_table[:starts_at].not_eq(nil))
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
    end

    def creator_or_platform_steward
      user.present? && (record.creator == agent || platform_event_manager?)
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

    def platform_event_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end

    # Pundit scope for event record visibility.
    class Scope < ApplicationPolicy::Scope
      private

      def platform_event_manager?
        permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
      end
    end
  end
end
