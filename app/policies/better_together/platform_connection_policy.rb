# frozen_string_literal: true

module BetterTogether
  class PlatformConnectionPolicy < ApplicationPolicy
    def index?
      can_view_network_connections?
    end

    def show?
      can_view_network_connections?
    end

    def create?
      can_manage_network_connections?
    end
    alias new? create?

    def update?
      can_manage_network_connections? || can_approve_network_connections?
    end
    alias edit? update?

    def approve?
      can_manage_network_connections? || can_approve_network_connections?
    end

    def suspend?
      can_manage_network_connections?
    end

    def destroy?
      can_manage_network_connections?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless can_view_network_connections?

        scope.includes(:source_platform, :target_platform).order(updated_at: :desc)
      end

      private

      def can_view_network_connections?
        permitted_to?('manage_network_connections') || permitted_to?('approve_network_connections')
      end
    end

    private

    def can_manage_network_connections?
      permitted_to?('manage_network_connections')
    end

    def can_approve_network_connections?
      permitted_to?('approve_network_connections')
    end

    def can_view_network_connections?
      can_manage_network_connections? || can_approve_network_connections?
    end
  end
end
