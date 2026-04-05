# frozen_string_literal: true

module BetterTogether
  module Safety
    # Builds a deterministic, local-only summary of the current review queue.
    class LocalReviewSnapshotService
      CACHE_KEY = 'better_together/safety/local_review_snapshot/v1'

      def initialize(case_scope: BetterTogether::Safety::Case.all, report_scope: BetterTogether::Report.all)
        @case_scope = case_scope
        @report_scope = report_scope
      end

      def call
        {
          generated_at: Time.current,
          open_cases_count: open_cases.count,
          urgent_open_cases_count: open_cases.where(harm_level: 'urgent').count,
          unassigned_open_cases_count: open_cases.where(assigned_reviewer_id: nil).count,
          retaliation_risk_open_cases_count: open_reports.where(retaliation_risk: true).count,
          repeated_reportables_count: repeated_reportables_count,
          participant_visible_notes_count: BetterTogether::Safety::Note.where(
            safety_case_id: open_cases.select(:id),
            visibility: 'participant_visible'
          ).count
        }
      end

      private

      attr_reader :case_scope, :report_scope

      def open_cases
        @open_cases ||= case_scope.open_cases
      end

      def open_reports
        @open_reports ||= report_scope.where(id: open_cases.select(:report_id))
      end

      def repeated_reportables_count
        open_reports
          .group(:reportable_type, :reportable_id)
          .having(Arel.sql('COUNT(*) > 1'))
          .count
          .size
      end
    end
  end
end
