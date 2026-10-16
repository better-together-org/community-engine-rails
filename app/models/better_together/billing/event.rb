# frozen_string_literal: true

module BetterTogether
  module Billing
    # Processor-neutral log of billing events, kept for audit, retry and replay.
    class Event < ApplicationRecord
      self.table_name = 'better_together_billing_events'

      MAX_ATTEMPTS = 5
      REPEATED_FAILURE_ATTEMPT_THRESHOLD = 3
      UNRESOLVED_ALERT_WINDOW = 6.hours
      DEFAULT_PAYLOAD_RETENTION_DAYS = 30
      ERROR_MESSAGE_LIMIT = 500
      PROCESSING_STATUSES = %w[pending processed failed ignored alerted dead_lettered replayed].freeze
      PROBLEM_STATUSES = %w[failed dead_lettered].freeze

      belongs_to :billable_owner, polymorphic: true, optional: true
      belongs_to :beneficiary, polymorphic: true, optional: true

      validates :processor, format: { with: /\A[a-z][a-z0-9_]*\z/ }
      validates :event_type, :event_id, presence: true
      validates :event_id, uniqueness: { scope: :processor }
      validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
      validate :owner_types_registered

      PROCESSING_STATUSES.each do |status|
        scope status.to_sym, -> { where(processing_status: status) }
        define_method(:"#{status}?") { processing_status == status }
      end

      scope :newest_first, -> { order(last_attempted_at: :desc, created_at: :desc) }
      scope :problematic, -> { where(processing_status: PROBLEM_STATUSES) }
      scope :with_retries, -> { where(arel_table[:attempt_count].gt(1)) }
      scope :repeated_failures, -> { failed.where(arel_table[:attempt_count].gteq(REPEATED_FAILURE_ATTEMPT_THRESHOLD)) }
      scope :payload_unredacted, -> { where(payload_redacted_at: nil) }
      scope :for_owner_or_beneficiary, lambda { |record|
        owner_match = arel_table[:billable_owner_type].eq(record.class.name).and(arel_table[:billable_owner_id].eq(record.id))
        beneficiary_match = arel_table[:beneficiary_type].eq(record.class.name).and(arel_table[:beneficiary_id].eq(record.id))
        where(owner_match.or(beneficiary_match))
      }

      class << self
        def payload_retention_days
          days = ENV.fetch('BT_BILLING_EVENT_PAYLOAD_RETENTION_DAYS', DEFAULT_PAYLOAD_RETENTION_DAYS).to_i
          days.positive? ? days : DEFAULT_PAYLOAD_RETENTION_DAYS
        end

        def payload_retention_expired
          payload_unredacted.where(reference_time(:processed_at, :created_at).lt(payload_retention_days.days.ago))
        end

        def unresolved_after_reconciliation_window
          problematic.where(reference_time(:last_attempted_at, :created_at).lteq(UNRESOLVED_ALERT_WINDOW.ago))
        end

        # Stuck events: retries exhausted, or no progress inside the alert window.
        def eligible_for_dead_lettering
          stuck = where(processing_status: %w[pending failed])
          exhausted = arel_table[:attempt_count].gteq(MAX_ATTEMPTS)
          stale = reference_time(:last_attempted_at, :created_at).lteq(UNRESOLVED_ALERT_WINDOW.ago)
          stuck.where(exhausted.or(stale))
        end

        def operator_alert_summary(scope = all)
          problems = scope.problematic
          unresolved = problems.unresolved_after_reconciliation_window
          {
            total_problematic_count: problems.count,
            failed_count: problems.failed.count,
            dead_lettered_count: problems.dead_lettered.count,
            repeated_failure_count: problems.repeated_failures.count,
            alerted_count: scope.alerted.count,
            unresolved_count: unresolved.count,
            oldest_unresolved_at: unresolved.minimum(:last_attempted_at) || unresolved.minimum(:created_at)
          }
        end

        def safe_error_message(error)
          error.message.to_s.truncate(ERROR_MESSAGE_LIMIT)
        end

        private

        def reference_time(first, second)
          Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[first], arel_table[second]])
        end
      end

      def problematic? = PROBLEM_STATUSES.include?(processing_status)

      def retrying? = attempt_count.to_i > 1

      def payload_redacted? = payload_redacted_at.present?

      def replayable_payload?
        !payload_redacted? && payload.to_h['id'].present? && payload.to_h['type'].present?
      end

      def status_badge_class
        { 'failed' => 'text-bg-danger', 'alerted' => 'text-bg-warning', 'dead_lettered' => 'text-bg-dark',
          'replayed' => 'text-bg-info' }.fetch(processing_status, 'text-bg-secondary')
      end

      def dead_letter!(reason:)
        update!(processing_status: 'dead_lettered', dead_lettered_at: Time.current, dead_letter_reason: reason)
      end

      def mark_replay_requested!(requested_by:)
        update!(
          processing_status: 'replayed', last_replayed_at: Time.current, replay_count: replay_count.to_i + 1,
          last_replay_requested_by_type: requested_by.class.name, last_replay_requested_by_id: requested_by.id,
          dead_lettered_at: nil, dead_letter_reason: nil, error_message: nil
        )
      end

      # Keeps identifiers, drops personal data. Fails closed to id/type when the
      # processor's adapter is no longer installed.
      def redact_payload!
        return if payload_redacted?

        adapter = BetterTogether::Billing.processor_adapter(processor)
        redacted = adapter ? adapter.sanitize_payload(payload) : payload.to_h.slice('id', 'type')
        update!(payload: redacted, payload_redacted_at: Time.current)
      end

      private

      def owner_types_registered
        registered = BetterTogether::Billing::Billable.model_names
        { billable_owner_type: billable_owner_type, beneficiary_type: beneficiary_type }.each do |attribute, type|
          errors.add(attribute, :inclusion) if type.present? && registered.exclude?(type)
        end
      end
    end
  end
end
