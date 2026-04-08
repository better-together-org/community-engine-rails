# frozen_string_literal: true

module BetterTogether
  # Authorization policy for user safety reports.
  class ReportPolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      user.present? && (record.reporter == agent || can_review_safety_disclosures?)
    end

    def new?
      create?
    end

    def create?
      user.present? && record.reportable.present? && record.reporter == agent && record.reporter != record.reportable
    end

    # Restricts report visibility to the reporting person and platform managers.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.all if permitted_to?('manage_platform_safety')
        return scope.none unless agent

        scope.where(reporter: agent).order(created_at: :desc)
      end
    end
  end
end
