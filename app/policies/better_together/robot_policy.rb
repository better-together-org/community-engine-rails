# frozen_string_literal: true

module BetterTogether
  # Policy for API-managed robot records.
  class RobotPolicy < ApplicationPolicy
    def index?
      manageable_platforms.any?
    end

    def show?
      manageable_robot?
    end

    def create?
      manageable_platform_robot?(record)
    end

    def update?
      manageable_platform_robot?(record)
    end

    def destroy?
      manageable_platform_robot?(record)
    end

    # Scope for robot records manageable through the API.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless manageable_platform_ids.any?

        scope.where(platform_id: manageable_platform_ids + [nil])
      end

      private

      def manageable_platform_ids
        return [] unless agent

        @manageable_platform_ids ||= BetterTogether::Platform
                                     .joins(:person_platform_memberships)
                                     .where(better_together_person_platform_memberships: { member_id: agent.id })
                                     .distinct
                                     .select do |platform|
          permitted_to?('manage_platform', platform) || permitted_to?('manage_platform_settings', platform)
        end
                                     .map(&:id)
      end
    end

    private

    def manageable_robot?
      record.global_fallback? || manageable_platform_robot?(record)
    end

    def manageable_platform_robot?(target)
      target.respond_to?(:platform_id) && target.platform_id.present? && manageable_platform_ids.include?(target.platform_id)
    end

    def manageable_platforms
      return [] unless agent

      @manageable_platforms ||= BetterTogether::Platform
                                .joins(:person_platform_memberships)
                                .where(better_together_person_platform_memberships: { member_id: agent.id })
                                .distinct
                                .select do |platform|
        permitted_to?('manage_platform', platform) || permitted_to?('manage_platform_settings', platform)
      end
    end

    def manageable_platform_ids
      @manageable_platform_ids ||= manageable_platforms.map(&:id)
    end
  end
end
