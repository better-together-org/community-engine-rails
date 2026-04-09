# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Tracks CE-local enforcement state for one attachment-bearing subject.
    class Subject < ApplicationRecord
      self.table_name = 'better_together_content_security_subjects'

      LIFECYCLE_STATES = {
        pending_scan: 'pending_scan',
        pending_private_review: 'pending_private_review',
        awaiting_lane_review: 'awaiting_lane_review',
        approved_private: 'approved_private',
        approved_public: 'approved_public',
        approved_ai_excluded: 'approved_ai_excluded',
        quarantined: 'quarantined',
        blocked_rejected: 'blocked_rejected'
      }.freeze

      AGGREGATE_VERDICTS = {
        clean: 'clean',
        review_required: 'review_required',
        restricted: 'restricted',
        quarantined: 'quarantined',
        blocked: 'blocked',
        override_released: 'override_released',
        false_positive: 'false_positive'
      }.freeze

      VISIBILITY_STATES = {
        private: 'private',
        public: 'public'
      }.freeze

      AI_INGESTION_STATES = {
        pending_review: 'pending_review',
        eligible: 'eligible',
        excluded: 'excluded'
      }.freeze

      RELEASED_LIFECYCLE_STATES = %w[approved_private approved_public approved_ai_excluded].freeze
      RELEASED_VERDICTS = %w[clean override_released false_positive].freeze
      REVIEW_QUEUE_LIFECYCLE_STATES = %w[
        pending_scan
        pending_private_review
        awaiting_lane_review
        quarantined
        blocked_rejected
      ].freeze

      belongs_to :subject, polymorphic: true
      belongs_to :active_storage_blob, class_name: '::ActiveStorage::Blob', optional: true

      enum :lifecycle_state, LIFECYCLE_STATES, prefix: :lifecycle_state
      enum :aggregate_verdict, AGGREGATE_VERDICTS, prefix: :aggregate_verdict
      enum :current_visibility_state, VISIBILITY_STATES, prefix: :current_visibility_state
      enum :current_ai_ingestion_state, AI_INGESTION_STATES, prefix: :current_ai_ingestion_state

      validates :attachment_name, presence: true
      validates :content_id, presence: true, uniqueness: true
      validates :source_surface, presence: true
      validates :storage_ref, presence: true

      before_validation :ensure_content_id, on: :create
      before_validation :ensure_storage_ref

      scope :for_blob, ->(blob) { where(active_storage_blob_id: blob.is_a?(::ActiveStorage::Blob) ? blob.id : blob) }
      scope :review_queue, lambda {
        where(lifecycle_state: REVIEW_QUEUE_LIFECYCLE_STATES)
          .where.not(aggregate_verdict: RELEASED_VERDICTS)
          .order(created_at: :desc)
      }

      def released_for_human_access?
        lifecycle_state.in?(RELEASED_LIFECYCLE_STATES) && aggregate_verdict.in?(RELEASED_VERDICTS)
      end

      def held_for_review?
        !released_for_human_access?
      end

      def publicly_serving_allowed?
        released_for_human_access? && current_visibility_state_public?
      end

      def reset_to_pending_review!
        assign_attributes(
          lifecycle_state: 'pending_scan',
          aggregate_verdict: 'review_required',
          current_visibility_state: 'private',
          current_ai_ingestion_state: 'pending_review',
          released_at: nil
        )
      end

      private

      def ensure_content_id
        return if content_id.present?

        base_ref = [
          'ce',
          subject_type.to_s.underscore.tr('/', '_').presence || 'subject',
          subject_id,
          attachment_name
        ].compact.join('_')

        self.content_id = base_ref
      end

      def ensure_storage_ref
        return unless active_storage_blob_id.present?

        self.storage_ref = "active_storage/blob/#{active_storage_blob_id}" if storage_ref.blank?
      end
    end
  end
end
