# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Deterministic regex/string content-safety checks, ported from the BTS management-tool's
    # content_safety_scanner_engine.py prototype so mail screening has no external process
    # dependency. Covers the technical, safety, and ai_integrity planes; real malware detection
    # is layered on top by DeterministicScanRunner via ClamAvClient.
    # rubocop:disable Metrics/ModuleLength
    module RuleEngine
      EICAR_SIGNATURE = 'x5o!p%@ap[4\\pzx54(p^)7cc)7}$eicar-standard-antivirus-test-file!$h+h*'

      MALWARE_ATTACHMENT_EXTENSIONS = %w[
        .exe .vbs .js .wsf .bat .cmd .scr .pif .jar .ps1 .hta .iso .img .docm .xlsm .pptm
      ].freeze

      PHISHING_URL_PATTERNS = [
        %r{https?://(?:\d{1,3}\.){3}\d{1,3}/}i,
        %r{bit\.ly|tinyurl\.com|t\.co/(?!witter)}i,
        /(?:verify|confirm|validate|update).*account.*(?:click|here|link)/i
      ].freeze

      INJECTION_PATTERNS = [
        /ignore (?:all )?(?:previous|prior|above) instructions?/i,
        /disregard (?:all )?(?:previous|prior|above) instructions?/i,
        /<system>/i,
        /\[SYSTEM\]/i,
        /what (?:are|is) your (?:system |hidden |secret )?(?:prompt|instructions?)/i,
        /print (?:all|every) (?:document|chunk|entry|record|item)/i,
        /reveal .{0,30} (?:password|secret|token|key|credential)/i
      ].freeze

      URL_PATTERN = %r{https?://[^\s<>'"]+}i
      EMAIL_PATTERN = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i
      PHONE_PATTERN = /(?:\+?1[\s.-]*)?(?:\(?\d{3}\)?[\s.-]*)\d{3}[\s.-]*\d{4}\b/
      SIN_PATTERN = /\b\d{3}[- ]?\d{3}[- ]?\d{3}\b/
      ADDRESS_CUE_PATTERN = /\b(?:address|home address|lives at|street|st\.|avenue|ave\.|road|rd\.|boulevard|blvd\.)\b/i

      VERDICT_PRECEDENCE = {
        'clean' => 0,
        'monitor' => 1,
        'review_required' => 2,
        'restricted' => 3,
        'quarantined' => 4,
        'blocked' => 5,
        'override_released' => -1,
        'false_positive' => -1
      }.freeze

      module_function

      def detect_urls(text)
        (text || '').scan(URL_PATTERN).map { |url| url.sub(/[.,;)]+\z/, '') }.uniq.sort
      end

      def summarize_plane_verdict(findings)
        return 'clean' if findings.empty?

        findings.max_by { |finding| VERDICT_PRECEDENCE.fetch(finding[:verdict], 0) }[:verdict]
      end

      # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      def build_finding(plane:, finding_type:, rule_id:, severity:, confidence:, verdict:, routing:, summary:, url_count: nil)
        {
          v: 'content_security.record.v1',
          record_type: 'finding',
          finding_id: SecureRandom.uuid,
          plane:,
          finding_type:,
          rule_id:,
          severity:,
          confidence:,
          verdict:,
          routing:,
          evidence: {
            capture_mode: 'excerpt',
            summary: summary[0, 500],
            url_count:
          },
          detected_at: Time.current.utc.iso8601
        }
      end
      # rubocop:enable Metrics/MethodLength, Metrics/ParameterLists

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def run_technical_scan(content_text, filename, blocked_domains: {})
        findings = []
        text = content_text || ''
        fname = filename.to_s.downcase
        urls = detect_urls(text)

        if text.downcase.include?(EICAR_SIGNATURE)
          findings << build_finding(
            plane: 'technical', finding_type: 'malware_test_signature', rule_id: 'clamav.eicar.test-string',
            severity: 'critical', confidence: 'high', verdict: 'quarantined',
            routing: { primary_lane: 'security', sla_bucket: 'immediate' },
            summary: 'EICAR test signature detected in content payload.', url_count: urls.size
          )
        end

        if fname.present? && MALWARE_ATTACHMENT_EXTENSIONS.any? { |ext| fname.end_with?(ext) }
          findings << build_finding(
            plane: 'technical', finding_type: 'suspicious_attachment_extension', rule_id: 'file.extension.high_risk',
            severity: 'high', confidence: 'medium', verdict: 'review_required',
            routing: { primary_lane: 'security', sla_bucket: 'same_day' },
            summary: "Filename #{fname.inspect} uses a high-risk executable or macro-capable extension.",
            url_count: urls.size
          )
        end

        urls.each do |url|
          hostname = URI.parse(url).host.to_s.downcase
          next unless blocked_domains.key?(hostname)

          findings << build_finding(
            plane: 'technical', finding_type: 'blocked_domain_reference', rule_id: 'threat_intel.local_blocklist.domain',
            severity: 'high', confidence: 'high', verdict: 'review_required',
            routing: { primary_lane: 'security', secondary_lanes: ['safety_moderation'], sla_bucket: 'same_day' },
            summary: "URL references locally blocked domain #{hostname}.", url_count: urls.size
          )
          break
        rescue URI::InvalidURIError
          next
        end

        if urls.any? && PHISHING_URL_PATTERNS.any? { |pattern| pattern.match?(text) }
          findings << build_finding(
            plane: 'technical', finding_type: 'phishing_pattern_reference', rule_id: 'correspondence.phishing_url_pattern',
            severity: 'medium', confidence: 'medium', verdict: 'review_required',
            routing: { primary_lane: 'security', sla_bucket: 'same_day' },
            summary: 'Text matched a high-risk phishing or account-verification URL pattern.', url_count: urls.size
          )
        end

        findings
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      # rubocop:disable Metrics/AbcSize
      def run_safety_scan(content_text)
        text = content_text || ''
        urls = detect_urls(text)
        email_count = text.scan(EMAIL_PATTERN).size
        phone_count = text.scan(PHONE_PATTERN).size
        has_sin = SIN_PATTERN.match?(text)
        has_address_cue = ADDRESS_CUE_PATTERN.match?(text)

        if has_sin || ((email_count + phone_count >= 2) && has_address_cue)
          [dense_disclosure_finding(urls.size)]
        elsif email_count.positive? || phone_count.positive?
          [personal_identifier_finding(urls.size)]
        else
          []
        end
      end
      # rubocop:enable Metrics/AbcSize

      def dense_disclosure_finding(url_count)
        build_finding(
          plane: 'safety', finding_type: 'possible_doxxing_or_sensitive_disclosure',
          rule_id: 'privacy.identifier_dense_disclosure', severity: 'high', confidence: 'medium',
          verdict: 'restricted',
          routing: { primary_lane: 'safety_moderation', secondary_lanes: ['governance_appeal'], sla_bucket: 'same_day' },
          summary: 'Deterministic rules found dense personal identifiers or address cues that may require private review.',
          url_count:
        )
      end

      def personal_identifier_finding(url_count)
        build_finding(
          plane: 'safety', finding_type: 'personal_identifier_detected', rule_id: 'privacy.identifier_present',
          severity: 'medium', confidence: 'medium', verdict: 'review_required',
          routing: { primary_lane: 'safety_moderation', sla_bucket: 'routine' },
          summary: 'Detected personal identifiers that may require privacy-aware review.', url_count:
        )
      end

      def run_ai_integrity_scan(content_text)
        text = content_text || ''
        urls = detect_urls(text)

        INJECTION_PATTERNS.each_with_index do |pattern, index|
          next unless pattern.match?(text)

          return [build_finding(
            plane: 'ai_integrity', finding_type: 'prompt_injection_pattern', rule_id: "rag.prompt_injection.#{index}",
            severity: 'high', confidence: 'medium', verdict: 'restricted',
            routing: { primary_lane: 'ai_integrity', secondary_lanes: ['security'], sla_bucket: 'immediate' },
            summary: "Matched prompt-injection or exfiltration pattern: #{pattern.source[0, 120]}",
            url_count: urls.size
          )]
        end

        []
      end

      def aggregate_content_state(findings)
        verdict = summarize_plane_verdict(findings)
        { aggregate_verdict: verdict, lifecycle_state: lifecycle_state_for(verdict) }
      end

      def lifecycle_state_for(verdict)
        case verdict
        when 'blocked' then 'blocked_rejected'
        when 'quarantined' then 'quarantined'
        when 'restricted', 'review_required' then 'awaiting_lane_review'
        else 'approved_private'
        end
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
