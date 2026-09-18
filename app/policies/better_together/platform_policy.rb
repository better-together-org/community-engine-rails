# frozen_string_literal: true

# app/policies/better_together/platform_policy.rb

module BetterTogether
  class PlatformPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present?
    end

    def show?
      public_or_member_scoped_community?(record) || can_manage_platform_settings?
    end

    # Platform creation (both internally-hosted tenant provisioning and external federation
    # peer registration) is restricted to stewards of the HOST platform specifically. A tenant
    # platform_steward's role grant lives on their own platform, never on the host platform, so
    # this stays correctly scoped even though platform_steward/platform_manager are also granted
    # create_platform generally (per-platform role grants only apply on the platform they were
    # granted on).
    def create?
      return false unless user.present?

      host_platform = ::BetterTogether::Platform.find_by(host: true)
      return false unless host_platform

      if record.external?
        user.permitted_to?('manage_network_connections', host_platform) ||
          user.permitted_to?('create_platform', host_platform)
      else
        user.permitted_to?('create_platform', host_platform)
      end
    end

    def new?
      create?
    end

    def update?
      user.present? && can_manage_platform_settings?
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && can_manage_platform_settings? && !record.protected? && !record.host?
    end

    def available_people?
      PersonPlatformMembershipPolicy.new(user, PersonPlatformMembership.new(joinable: record)).create?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        results = scope.order(:host, :identifier)

        # This index backs the host's own /host/platforms tenant-fleet screen, so whoever
        # manages the HOST platform legitimately sees every tenant platform there (that's the
        # multi-tenant hosting operator experience). A steward of a single TENANT platform gets
        # no such fleet-wide visibility — only their own managed platform(s) plus whatever is
        # otherwise publicly/community visible.
        return results if manages_host_platform?

        results.where(id: managed_platform_ids).or(results.where(visible_privacy_query(scope.arel_table)))
      end

      private

      def manages_host_platform?
        return false unless agent

        host_platform = BetterTogether::Platform.find_by(host: true)
        return false unless host_platform

        permitted_to?('manage_platform_settings', host_platform) || permitted_to?('manage_platform', host_platform)
      end

      # Mirrors RobotPolicy::Scope#manageable_platform_ids: a person can only manage the
      # platforms they hold manage_platform/manage_platform_settings on via their own
      # per-platform role grant, not every platform in the installation.
      def managed_platform_ids
        return [] unless agent

        BetterTogether::Platform
          .joins(:person_platform_memberships)
          .where(better_together_person_platform_memberships: { member_id: agent.id })
          .distinct
          .select do |platform|
          permitted_to?('manage_platform_settings', platform) || permitted_to?('manage_platform', platform)
        end
          .map(&:id)
      end
    end

    private

    def can_manage_platform_settings?(target = record)
      user.permitted_to?('manage_platform_settings', target) || user.permitted_to?('manage_platform', target)
    end
  end
end
