# frozen_string_literal: true

module BetterTogether
  # Shared host-membership authorization logic for anything that should be
  # managed by an Event's own creator/hosts — used by both EventPolicy
  # (checking the event itself) and EventOccurrencePolicy (checking the
  # parent event of an occurrence, so per-occurrence authorization never
  # requires duplicating EventHost/creator data).
  module EventHostAuthorizable
    extend ActiveSupport::Concern

    # The Event whose event_hosts/creator should be checked. Override in
    # including policies whose `record` isn't itself the Event (e.g.
    # EventOccurrencePolicy, where `record.event` is the Event).
    def event_for_authorization
      record
    end

    def event_host_member?
      return false unless user.present?

      event = event_for_authorization
      can_represent_host = event.event_hosts.any? && agent.valid_event_host_ids.any?

      # .map (not .pluck) — pluck always hits the DB directly, which returns
      # empty for a new/unsaved record's in-memory .build'd event_hosts
      # (e.g. during authorization on the `new`/`create` actions, before the
      # event is persisted).
      has_common_hosts = event.event_hosts.map(&:host_id).intersect?(agent.valid_event_host_ids)
      can_represent_host && has_common_hosts
    end

    def community_event_manager?
      return false unless user.present?

      community_host_ids = event_for_authorization.event_hosts
                                                  .select { |h| h.host_type == 'BetterTogether::Community' }
                                                  .map(&:host_id)
      return false if community_host_ids.empty?

      community_host_ids.any? do |community_id|
        community = BetterTogether::Community.find_by(id: community_id)
        next false unless community

        permitted_to?('manage_community_events', community)
      end
    end

    def creator_or_platform_steward
      user.present? && (creator_of?(event_for_authorization) || platform_manager?)
    end
  end
end
