# frozen_string_literal: true

module BetterTogether
  # Authorization for shared feedback-surface visibility and action availability.
  class FeedbackPolicy < ApplicationPolicy
    def show?
      report?
    end
    alias show_surface? show?

    def report?
      return false unless user.present? && agent.present? && record.present?
      return false unless reportable_record?

      report_policy.create?
    end

    def contribute_feedback?
      false
    end

    def contribute_response?
      false
    end

    def publish_without_moderation?
      false
    end

    def moderation_required?
      false
    end

    private

    def reportable_record?
      BetterTogether::Report::ALLOWED_REPORTABLES.include?(record.class.base_class.name)
    end

    def report_policy
      BetterTogether::ReportPolicy.new(user, report_record)
    end

    def report_record
      BetterTogether::Report.new(
        reporter: agent,
        reportable: record,
        reason: 'feedback-surface-policy-check'
      )
    end
  end
end
