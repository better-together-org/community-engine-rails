# frozen_string_literal: true

module BetterTogether
  module Safety
    # Builds a deterministic, local-only summary of the current review queue.
    class LocalReviewSnapshotService
      CACHE_KEY = 'better_together/safety/local_review_snapshot/v1'

      def initialize(
        case_scope: BetterTogether::Safety::Case.all,
        report_scope: BetterTogether::Report.all,
        content_security_subject_scope: BetterTogether::ContentSecurity::Subject.all
      )
        @case_scope = case_scope
        @report_scope = report_scope
        @content_security_subject_scope = content_security_subject_scope
      end

      def call
        base_snapshot.merge(content_review_snapshot).merge(participant_notes_snapshot)
      end

      private

      attr_reader :case_scope, :report_scope, :content_security_subject_scope

      def base_snapshot
        {
          generated_at: Time.current,
          open_cases_count: open_cases.count,
          urgent_open_cases_count: open_cases.where(harm_level: 'urgent').count,
          unassigned_open_cases_count: open_cases.where(assigned_reviewer_id: nil).count,
          retaliation_risk_open_cases_count: open_reports.where(retaliation_risk: true).count,
          repeated_reportables_count: repeated_reportables_count
        }
      end

      def content_review_snapshot
        { content_review_items_count: content_security_subject_scope.review_queue.count }
      end

      def participant_notes_snapshot
        {
          participant_visible_notes_count: BetterTogether::Safety::Note.where(
            safety_case_id: open_cases.select(:id),
            visibility: 'participant_visible'
          ).count
        }
      end

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
