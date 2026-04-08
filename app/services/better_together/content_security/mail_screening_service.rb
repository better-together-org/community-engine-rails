# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Builds shared-contract intake payloads for inbound mail and holds routing unless screening passes.
    class MailScreeningService
      Result = Struct.new(:allow_routing?, :screening_state, :screening_verdict)

      PASSABLE_VERDICTS = %w[clean monitor].freeze
      VERDICT_PRECEDENCE = {
        'clean' => 0,
        'monitor' => 1,
        'review_required' => 2,
        'restricted' => 3,
        'quarantined' => 4,
        'blocked' => 5
      }.freeze

      def initialize(scanner_runner: nil, **context)
        @context = context
        @scanner_runner = scanner_runner || BetterTogether::ContentSecurity::OrchestratorRunner.new
      end

      def screen!(message)
        results = payload_builder.call(message).map { |payload| @scanner_runner.call(payload) }
        verdict = aggregate_verdict(results)
        screening_state = PASSABLE_VERDICTS.include?(verdict) ? 'passed' : 'held'

        persist_screening_result(message, results:, verdict:, screening_state:)
      rescue BetterTogether::ContentSecurity::OrchestratorRunner::Error => e
        persist_scanner_error(message, e)
      end

      private

      def payload_builder
        @payload_builder ||= BetterTogether::ContentSecurity::MailScreeningPayloadBuilder.new(**@context)
      end

      def persist_screening_result(message, results:, verdict:, screening_state:)
        message.update!(
          screening_state:,
          screening_verdict: verdict,
          content_screening_summary: summary_for(results, verdict),
          content_security_records: results.flat_map { |result| Array(result['records']) }
        )

        Result.new(screening_state == 'passed', screening_state, verdict)
      end

      def persist_scanner_error(message, error)
        message.update!(
          screening_state: 'error',
          screening_verdict: 'review_required',
          content_screening_summary: error.message,
          content_security_records: []
        )

        Result.new(false, 'error', 'review_required')
      end

      def aggregate_verdict(results)
        verdicts = results.map { |result| result.dig('content_item', 'aggregate_verdict').presence || 'review_required' }
        verdicts.max_by { |verdict| VERDICT_PRECEDENCE.fetch(verdict, VERDICT_PRECEDENCE['review_required']) }
      end

      def summary_for(results, verdict)
        finding_summaries = results.flat_map { |result| Array(result['findings']).map { |finding| finding['summary'] } }.compact
        if finding_summaries.blank? && PASSABLE_VERDICTS.include?(verdict)
          return 'Content safety screening passed for inbound email and attachments.'
        end

        [verdict.humanize, *finding_summaries].join(': ')
      end
    end
  end
end
