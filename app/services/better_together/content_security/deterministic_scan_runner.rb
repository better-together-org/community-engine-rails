# frozen_string_literal: true

require 'tempfile'

module BetterTogether
  module ContentSecurity
    # Native Ruby replacement for OrchestratorRunner. Runs the deterministic technical/safety/
    # ai_integrity checks from RuleEngine plus a real ClamAV scan (when raw attachment bytes are
    # present and malware scanning is enabled for the 'mail' surface), with no external process
    # or management-tool dependency. Returns the same content_item/findings/records shape
    # MailScreeningService already expects from OrchestratorRunner.
    class DeterministicScanRunner
      def call(payload)
        content_text = payload[:content_text].to_s
        filename = payload.dig(:object, :filename)

        findings = RuleEngine.run_technical_scan(content_text, filename) +
                   RuleEngine.run_safety_scan(content_text) +
                   RuleEngine.run_ai_integrity_scan(content_text) +
                   malware_findings(payload)

        aggregate = RuleEngine.aggregate_content_state(findings)
        stringified_findings = findings.map(&:deep_stringify_keys)

        {
          'content_item' => aggregate.deep_stringify_keys,
          'findings' => stringified_findings,
          'records' => stringified_findings
        }
      end

      private

      def malware_findings(payload)
        raw_content = payload[:raw_content]
        return [] if raw_content.blank?
        return [] unless Configuration.enabled? && Configuration.enabled_for_surface?('mail')

        scan_raw_content(raw_content, payload.dig(:object, :filename))
      end

      def scan_raw_content(raw_content, filename)
        response = scan_via_tempfile(raw_content)
        return [] if response.fetch(:status) == :clean

        [malware_finding(filename, response.fetch(:signature_name))]
      rescue ClamAvClient::Error => e
        [scan_error_finding(e)]
      end

      def scan_via_tempfile(raw_content)
        Tempfile.create('bt-mail-scan', binmode: true) do |file|
          file.write(raw_content)
          file.flush
          Configuration.build_client.scan_file(file.path)
        end
      end

      def malware_finding(filename, signature_name)
        RuleEngine.build_finding(
          plane: 'technical', finding_type: 'malware_signature', rule_id: "clamav.#{signature_name}",
          severity: 'critical', confidence: 'high', verdict: 'quarantined',
          routing: { primary_lane: 'security', sla_bucket: 'immediate' },
          summary: "ClamAV detected #{signature_name} in #{filename || 'attachment'}."
        )
      end

      def scan_error_finding(error)
        RuleEngine.build_finding(
          plane: 'technical', finding_type: 'malware_scan_error', rule_id: 'clamav.scan_error',
          severity: 'high', confidence: 'medium', verdict: 'review_required',
          routing: { primary_lane: 'security', sla_bucket: 'same_day' },
          summary: "ClamAV scan failed: #{error.message}"
        )
      end
    end
  end
end
