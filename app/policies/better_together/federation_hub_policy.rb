# frozen_string_literal: true

module BetterTogether
  # Policy for the Federation Hub — open to any authenticated person so
  # everyone can see their own content's federation status. Admin sections
  # (connection health, pending review counts) are gated inline within the
  # hub by manage_connections_section?, not by hub access itself.
  class FederationHubPolicy < ApplicationPolicy
    def show?
      user.present?
    end

    def activity?
      show?
    end

    # True when the current agent may see connection-health / pending-review
    # / aggregate-stats sections inside the hub.
    def manage_connections_section?
      return false unless user

      user.permitted_to?('manage_network_connections') || user.permitted_to?('approve_network_connections')
    end
  end
end
