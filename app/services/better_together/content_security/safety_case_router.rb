# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Routes content-security findings to BetterTogether safety cases and reports.
    class SafetyCaseRouter
      class << self
        def route!(item:, finding:)
          attachable = item.attachable
          reporter = attachable.try(:creator)
          return unless attachable.is_a?(BetterTogether::Upload)
          return unless reporter.is_a?(BetterTogether::Person)

          report = BetterTogether::Report.find_or_initialize_by(reporter: reporter, reportable: attachable)
          populate_report!(report, finding)
          safety_case = report.safety_case
          link_safety_case!(item, finding, safety_case)
          create_internal_note!(safety_case, reporter, finding)
        end

        private

        def report_category(finding)
          finding.finding_type == 'malware_signature' ? 'malware_detected' : 'scan_failure'
        end

        def report_reason(finding)
          if finding.finding_type == 'malware_signature'
            "Malware detected during upload scanning: #{finding.rule_id}"
          else
            'Malware scanning failed and the upload is being held for review.'
          end
        end

        def populate_report!(report, finding)
          report.reason = report_reason(finding)
          report.category = report_category(finding)
          report.harm_level = finding.verdict == 'quarantined' ? 'high' : 'medium'
          report.requested_outcome = 'content_review'
          report.private_details = finding.evidence_summary
          set_report_consent_defaults!(report)
          report.save!
        end

        def set_report_consent_defaults!(report)
          report.consent_to_contact = true if report.consent_to_contact.nil?
          report.consent_to_restorative_process = false if report.consent_to_restorative_process.nil?
          report.retaliation_risk = false if report.retaliation_risk.nil?
        end

        def link_safety_case!(item, finding, safety_case)
          item.update!(safety_case:) if item.safety_case != safety_case
          finding.update!(safety_case:) if finding.safety_case != safety_case
        end

        def create_internal_note!(safety_case, reporter, finding)
          safety_case.notes.create!(
            author: reporter,
            visibility: 'internal_only',
            body: finding.evidence_summary
          )
        end
      end
    end
  end
end
