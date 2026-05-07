# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Background job that scans an attachment blob and updates the Item lifecycle accordingly.
    class ScanAttachmentJob < BetterTogether::ApplicationJob
      queue_as :default

      discard_on ActiveJob::DeserializationError
      discard_on ActiveRecord::RecordNotFound

      # Retry transient clamd connection failures (restart, brief outage) before escalating.
      # After exhaustion the item stays pending_scan; a monitoring alert should surface stale items.
      retry_on BetterTogether::ContentSecurity::ClamAvClient::ConnectionError,
               wait: :polynomially_longer, attempts: 3

      def perform(item_id)
        item = BetterTogether::ContentSecurity::Item.find(item_id)
        return if item_already_assessed?(item)

        started_at = Time.current
        result = BetterTogether::ContentSecurity::Scanner.scan_blob(item.blob)
        finished_at = Time.current

        # Re-raise so retry_on can handle transient connection failures without creating a safety case.
        raise BetterTogether::ContentSecurity::ClamAvClient::ConnectionError, result.error_summary if clamav_connection_error?(result)

        scan_event = create_scan_event!(item, result, started_at:, finished_at:)
        apply_result!(item, result, scan_event)
      end

      private

      def item_already_assessed?(item)
        item.lifecycle_state_clean? || item.lifecycle_state_quarantined? || item.lifecycle_state_blocked?
      end

      def clamav_connection_error?(result)
        result.status == :error && result.error_class == 'clamav_connection_error'
      end

      def create_scan_event!(item, result, started_at:, finished_at:)
        item.scan_events.create!(
          status: scan_event_status(result),
          plane: 'technical',
          scanner_name: result.scanner_name,
          scanner_version: result.scanner_version,
          verdict: result.verdict,
          signature_name: result.signature_name,
          error_class: result.error_class,
          error_summary: result.error_summary,
          started_at:,
          finished_at:
        )
      end

      def apply_result!(item, result, scan_event)
        case result.status
        when :clean
          apply_clean_result!(item, result)
        when :infected
          apply_infected_result!(item, result, scan_event)
        else
          apply_error_result!(item, result, scan_event)
        end
      rescue ActiveRecord::StaleObjectError
        # A concurrent job already processed this item (optimistic locking conflict).
        # The first writer wins; discard our result rather than crashing.
        Rails.logger.info "[ScanAttachmentJob] Stale object conflict for item #{item.id} — discarding duplicate result"
      end

      def apply_clean_result!(item, result)
        item.update!(
          lifecycle_state: 'clean', aggregate_verdict: 'clean',
          scanner_name: result.scanner_name, scanned_at: Time.current,
          released_at: Time.current, last_error_class: nil, last_error_summary: nil
        )
      end

      def apply_infected_result!(item, result, scan_event)
        finding = create_finding!(
          item:, scan_event:, finding_type: 'malware_signature',
          rule_id: result.signature_name, severity: 'high', confidence: 'high',
          verdict: 'quarantined',
          evidence_summary: "ClamAV detected #{result.signature_name} on upload #{item.attachable_type}##{item.attachable_id}."
        )
        item.update!(
          lifecycle_state: 'quarantined', aggregate_verdict: 'quarantined',
          scanner_name: result.scanner_name, scanned_at: Time.current,
          last_error_class: nil, last_error_summary: nil
        )
        BetterTogether::ContentSecurity::SafetyCaseRouter.route!(item:, finding:)
      end

      def apply_error_result!(item, result, scan_event)
        return hold_pending!(item, result) if hold_until_clean?

        escalate_to_review!(item, result, scan_event)
      end

      def hold_until_clean?
        BetterTogether::ContentSecurity::Configuration.fail_mode == 'hold_until_clean'
      end

      # Hold access without escalating — item stays pending_scan; last_error_* recorded for
      # debugging. Prevents scan outages from flooding the safety case queue.
      def hold_pending!(item, result)
        item.update!(last_error_class: result.error_class, last_error_summary: result.error_summary)
      end

      def escalate_to_review!(item, result, scan_event)
        finding = create_finding!(
          item:, scan_event:, finding_type: 'scanner_error',
          rule_id: result.error_class, severity: 'medium', confidence: 'medium',
          verdict: 'review_required',
          evidence_summary: "Malware scanning failed for upload #{item.attachable_type}##{item.attachable_id}: #{result.error_summary}"
        )
        item.update!(
          lifecycle_state: 'review_required', aggregate_verdict: 'review_required',
          scanner_name: result.scanner_name, scanned_at: Time.current,
          released_at: nil, last_error_class: result.error_class, last_error_summary: result.error_summary
        )
        BetterTogether::ContentSecurity::SafetyCaseRouter.route!(item:, finding:)
      end

      def create_finding!(**params)
        item = params.delete(:item)
        item.findings.create!(**params, plane: 'technical', detected_at: Time.current)
      end

      def scan_event_status(result)
        result.status == :error ? 'failed' : 'completed'
      end
    end
  end
end
