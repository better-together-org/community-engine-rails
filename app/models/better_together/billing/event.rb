# frozen_string_literal: true

module BetterTogether
  module Billing
    # Raw billing event log retained for auditability and replay.
    # rubocop:disable Metrics/ClassLength
    class Event < ApplicationRecord
      self.table_name = 'better_together_billing_events'

      PAYLOAD_RETENTION_DAYS = 30
      REPEATED_FAILURE_ATTEMPT_THRESHOLD = 3
      UNRESOLVED_ALERT_WINDOW = 6.hours
      PROCESSORS = %w[stripe].freeze
      SUPPORTED_OWNER_TYPES = %w[BetterTogether::Community BetterTogether::Person].freeze
      PROCESSING_STATUSES = %w[pending processed failed ignored dead_lettered replayed].freeze

      belongs_to :billable_owner,
                 polymorphic: true,
                 optional: true
      belongs_to :billing_subscription,
                 class_name: 'BetterTogether::Billing::Subscription',
                 optional: true,
                 inverse_of: :billing_events

      validates :processor, inclusion: { in: PROCESSORS }
      validates :event_type, :event_id, presence: true
      validates :event_id, uniqueness: { scope: :processor }
      validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
      validate :billable_owner_type_supported

      scope :pending, -> { where(processing_status: 'pending') }
      scope :failed, -> { where(processing_status: 'failed') }
      scope :ignored, -> { where(processing_status: 'ignored') }
      scope :dead_lettered, -> { where(processing_status: 'dead_lettered') }
      scope :newest_first, -> { order(last_attempted_at: :desc, created_at: :desc) }
      scope :problematic, -> { where(processing_status: %w[failed ignored dead_lettered]) }
      scope :with_retries, -> { where(arel_table[:attempt_count].gt(1)) }
      scope :repeated_failures, -> { failed.where(arel_table[:attempt_count].gteq(REPEATED_FAILURE_ATTEMPT_THRESHOLD)) }
      scope :payload_unredacted, -> { where(payload_redacted_at: nil) }

      def processed?
        processing_status == 'processed'
      end

      def failed?
        processing_status == 'failed'
      end

      def ignored?
        processing_status == 'ignored'
      end

      def dead_lettered?
        processing_status == 'dead_lettered'
      end

      def replayed?
        processing_status == 'replayed'
      end

      def problematic?
        failed? || ignored? || dead_lettered?
      end

      def retrying?
        attempt_count.to_i > 1
      end

      def status_badge_class
        return 'text-bg-danger' if failed?
        return 'text-bg-warning' if ignored?
        return 'text-bg-dark' if dead_lettered?
        return 'text-bg-info' if replayed?

        'text-bg-secondary'
      end

      def replayable_payload?
        payload_redacted_at.blank? && payload.to_h['id'].present? && payload.to_h['type'].present?
      end

      def dead_letter!(reason:)
        update!(
          processing_status: 'dead_lettered',
          dead_lettered_at: Time.current,
          dead_letter_reason: reason
        )
      end

      def mark_replay_requested!(requested_by:)
        update!(
          processing_status: 'replayed',
          last_replayed_at: Time.current,
          replay_count: replay_count.to_i + 1,
          last_replay_requested_by_type: requested_by.class.name,
          last_replay_requested_by_id: requested_by.id,
          dead_lettered_at: nil,
          dead_letter_reason: nil,
          error_message: nil
        )
      end

      def community
        billable_owner if billable_owner.is_a?(BetterTogether::Community)
      end

      def person
        billable_owner if billable_owner.is_a?(BetterTogether::Person)
      end

      def redact_payload!
        return if payload_redacted_at.present?

        update!(
          payload: BetterTogether::Billing::StripeEventPayloadSanitizer.new.call(payload),
          payload_redacted_at: Time.current
        )
      end

      def payload_redacted?
        payload_redacted_at.present?
      end

      class << self
        def operator_alert_summary(scope = all)
          problematic_scope = scope.problematic
          unresolved_scope = problematic_scope.unresolved_after_reconciliation_window

          {
            total_problematic_count: problematic_scope.count,
            failed_count: problematic_scope.failed.count,
            ignored_count: problematic_scope.ignored.count,
            dead_lettered_count: problematic_scope.dead_lettered.count,
            repeated_failure_count: problematic_scope.repeated_failures.count,
            unresolved_count: unresolved_scope.count,
            oldest_unresolved_at: unresolved_scope.minimum(:last_attempted_at) || unresolved_scope.minimum(:created_at)
          }
        end

        def payload_retention_expired
          payload_unredacted.where(payload_reference_time_column.lt(payload_redaction_cutoff_time))
        end

        def unresolved_after_reconciliation_window
          problematic.where(alert_reference_time_column.lteq(unresolved_alert_cutoff_time))
        end

        def eligible_for_dead_lettering
          retry_threshold_reached = arel_table[:attempt_count].gteq(REPEATED_FAILURE_ATTEMPT_THRESHOLD)
          stale_unresolved_event = alert_reference_time_column.lteq(unresolved_alert_cutoff_time)
          retry_or_stale = retry_threshold_reached.or(stale_unresolved_event)

          problematic.where.not(processing_status: 'dead_lettered').where(retry_or_stale)
        end

        def payload_redaction_cutoff_time
          PAYLOAD_RETENTION_DAYS.days.ago
        end

        def unresolved_alert_cutoff_time
          UNRESOLVED_ALERT_WINDOW.ago
        end

        private

        def payload_reference_time_column
          Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[:processed_at], arel_table[:created_at]])
        end

        def alert_reference_time_column
          Arel::Nodes::NamedFunction.new('COALESCE', [arel_table[:last_attempted_at], arel_table[:created_at]])
        end
      end

      private

      def billable_owner_type_supported
        return if billable_owner_type.blank? || billable_owner_type.in?(SUPPORTED_OWNER_TYPES)

        errors.add(:billable_owner_type, :inclusion)
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
