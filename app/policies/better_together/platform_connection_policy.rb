# frozen_string_literal: true

module BetterTogether
  # Pundit policy governing who can view, create, approve, suspend, and
  # manage federation platform connections.
  class PlatformConnectionPolicy < ApplicationPolicy
    def index?
      feature_enabled?('platform_federation_tools') && can_view_network_connections?
    end

    def show?
      feature_enabled?('platform_federation_tools') && can_view_network_connections?
    end

    def create?
      feature_enabled?('platform_federation_tools') && can_manage_network_connections?
    end
    alias new? create?

    def update?
      feature_enabled?('platform_federation_tools') && can_manage_network_connections?
    end
    alias edit? update?

    def approve?
      feature_enabled?('platform_federation_tools') && (can_manage_network_connections? || can_approve_network_connections?)
    end

    def suspend?
      feature_enabled?('platform_federation_tools') && can_manage_network_connections?
    end

    def destroy?
      feature_enabled?('platform_federation_tools') && can_manage_network_connections?
    end

    def rotate_secret?
      feature_enabled?('platform_federation_tools') && can_manage_network_connections?
    end

    # Scopes platform connections to those whose local side (source or target,
    # whichever platform is actually hosted on this instance) the current user
    # is permitted to view - not every connection any platform happens to have.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless feature_enabled?('platform_federation_tools')
        return scope.none unless agent

        base = scope.includes(:source_platform, :target_platform)
        ids = viewable_platform_ids

        base.where(source_platform_id: ids).or(base.where(target_platform_id: ids)).order(updated_at: :desc)
      end

      private

      def viewable_platform_ids
        @viewable_platform_ids ||= BetterTogether::Platform
                                   .joins(:person_platform_memberships)
                                   .where(better_together_person_platform_memberships: { member_id: agent.id })
                                   .distinct
                                   .select do |platform|
                                     permitted_to?('manage_network_connections', platform) ||
                                       permitted_to?('approve_network_connections', platform)
                                   end
                                    .map(&:id)
      end
    end

    private

    # The platform whose managers should be authorized for this connection:
    # its local side for an existing connection, otherwise the acting
    # person's own platform context. create?/new? deliberately never derive
    # authorization from record.source_platform_id/target_platform_id -
    # those are attacker-controlled request params on an unsaved record, so
    # deriving the target from them would let anyone name their own platform
    # as one side of a brand-new connection to bootstrap authorization to
    # link it against an arbitrary platform on the other side.
    def contextual_platform
      return record.local_platform if record.is_a?(::BetterTogether::PlatformConnection) && record.persisted?

      ::Current.platform || ::Current.host_platform
    end

    def can_manage_network_connections?
      permitted_to?('manage_network_connections', contextual_platform)
    end

    def can_approve_network_connections?
      permitted_to?('approve_network_connections', contextual_platform)
    end

    def can_view_network_connections?
      can_manage_network_connections? || can_approve_network_connections?
    end
  end
end
