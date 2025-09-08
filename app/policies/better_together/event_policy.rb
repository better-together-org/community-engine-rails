# frozen_string_literal: true

module BetterTogether
  # Access control for calendars
  class EventPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      (record.privacy_public? && record.starts_at.present?) || creator_or_manager || event_host_member?
    end

    def ics?
      record.starts_at.present? && show?
    end

    def update?
      creator_or_manager || event_host_member?
    end

    def create?
      permitted_to?('manage_platform') || event_host_member?
    end

    def destroy?
      creator_or_manager || event_host_member?
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
             .includes(:string_translations, :text_translations, :location, :event_hosts, categorizations: {
                         category: %i[
                           string_translations cover_image_attachment cover_image_blob
                         ]
                       }).order(
                         starts_at: :desc, created_at: :desc
                       ).where(permitted_query)
      end

      protected

      # rubocop:todo Metrics/MethodLength
      def permitted_query # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        events_table = ::BetterTogether::Event.arel_table
        event_hosts_table = ::BetterTogether::EventHost.arel_table

        # Only list events that are public and where the current person is a member or a creator
        query = events_table[:privacy].eq('public')

        if permitted_to?('manage_platform')
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

          query
        else
          # Events must have a start time to be shown to people who aren't conencted to the event
          query = query.and(events_table[:starts_at].not_eq(nil))
        end

        query
      end
      # rubocop:enable Metrics/MethodLength
    end

    def creator_or_manager
      user.present? && (record.creator == agent || permitted_to?('manage_platform'))
    end
  end
end
