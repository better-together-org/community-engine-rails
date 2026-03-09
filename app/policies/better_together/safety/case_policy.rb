# frozen_string_literal: true

module BetterTogether
  module Safety
    # Authorization policy for safety cases.
    class CasePolicy < ApplicationPolicy
      def index?
        platform_manager?
      end

      def show?
        platform_manager? || reporter?
      end

      def update?
        platform_manager?
      end

      # Limits case visibility to platform managers or the reporting person.
      class Scope < ApplicationPolicy::Scope
        def resolve
          return scope.all if agent&.permitted_to?('manage_platform')
          return scope.none unless agent

          scope.joins(:report).where(better_together_reports: { reporter_id: agent.id })
        end
      end

      private

      def reporter?
        record.report.reporter == agent
      end

      def platform_manager?
        agent&.permitted_to?('manage_platform')
      end
    end
  end
end
