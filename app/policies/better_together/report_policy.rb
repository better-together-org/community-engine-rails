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
      user.present? && record.reportable.present? && record.reporter == agent && !self_report?
    end

    def add_followup?
      user.present? && record.reporter == agent && record.safety_case.present?
    end

    # Restricts report visibility to the reporting person and platform managers.
    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.all if permitted_to?('manage_platform_safety')
        return scope.none unless agent

        scope.where(reporter: agent).order(created_at: :desc)
      end
    end

    private

    def self_report?
      return true if record.reporter == record.reportable

      owned_by_agent?(record.reportable)
    end

    def owned_by_agent?(reportable)
      return true if reportable.respond_to?(:creator) && reportable.creator == agent
      return true if reportable.respond_to?(:author) && reportable.author == agent
      return true if reportable.respond_to?(:authors) && reportable.authors.include?(agent)

      false
    end
  end
end
