# frozen_string_literal: true

module BetterTogether
  # Tracks seed import and tending operations.
  class SeedPlanting < ApplicationRecord
    self.table_name = 'better_together_seed_plantings'

    include Creatable
    include Privacy

    STATUS_VALUES = {
      pending: 'pending',
      in_progress: 'in_progress',
      completed: 'completed',
      failed: 'failed',
      cancelled: 'cancelled'
    }.freeze

    PLANTING_TYPES = {
      seed: 'seed',
      bulk_data: 'bulk_data',
      configuration: 'configuration',
      federated_tending: 'federated_tending'
    }.freeze

    belongs_to :seed, class_name: 'BetterTogether::Seed', optional: true

    enum :status, STATUS_VALUES, default: :pending, validate: true
    enum :planting_type, PLANTING_TYPES, default: :seed, validate: true

    validates :metadata, presence: true

    def mark_started!(started_time = Time.current)
      update!(
        status: :in_progress,
        started_at: started_time,
        metadata: metadata.merge('started_at' => started_time.iso8601)
      )
    end

    def mark_completed!(result_data = {})
      completed_time = Time.current
      update!(
        status: :completed,
        completed_at: completed_time,
        result: result_data,
        metadata: metadata.merge('completed_at' => completed_time.iso8601)
      )
    end

    def mark_failed!(error)
      failed_time = Time.current
      update!(
        status: :failed,
        completed_at: failed_time,
        error_message: error.to_s,
        metadata: metadata.merge('failed_at' => failed_time.iso8601)
      )
    end
  end
end
