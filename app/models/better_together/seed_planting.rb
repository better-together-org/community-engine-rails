# frozen_string_literal: true

module BetterTogether
  # Tracks planting operations for seeds and other data import processes
  class SeedPlanting < ApplicationRecord
    self.table_name = 'better_together_seed_plantings'

    include Creatable
    include Privacy

    # Status enum for tracking planting progress
    enum :status, {
      pending: 'pending',
      in_progress: 'in_progress',
      completed: 'completed',
      failed: 'failed',
      cancelled: 'cancelled'
    }

    # Planting type enum for different kinds of plantings
    enum :planting_type, {
      seed: 'seed',
      bulk_data: 'bulk_data',
      configuration: 'configuration'
    }

    # Associations
    # Note: creator association provided by Creatable concern
    alias_method :planted_by, :creator
    alias_method :planted_by=, :creator=
    
    belongs_to :seed, class_name: 'BetterTogether::Seed', optional: true

    # Validations
    validates :status, :planting_type, presence: true
    validates :metadata, presence: true
    validate :completed_at_presence_for_terminal_states
    validate :error_message_presence_for_failed_state

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :active, -> { where(status: %w[pending in_progress]) }
    scope :terminal, -> { where(status: %w[completed failed cancelled]) }
    scope :successful, -> { where(status: 'completed') }
    scope :failed_plantings, -> { where(status: 'failed') }

    # Callbacks
    # before_validation :set_started_at, if: :status_changed_to_in_progress?
    # before_validation :set_completed_at, if: :status_changed_to_terminal?

    # Instance methods
    def duration
      return nil unless started_at && completed_at

      completed_at - started_at
    end

    def success?
      completed?
    end

    def terminal?
      completed? || failed? || cancelled?
    end

    def active?
      pending? || in_progress?
    end

    def progress_percentage
      return 0 unless metadata.present?

      total = metadata.dig('progress', 'total')&.to_f
      processed = metadata.dig('progress', 'processed')&.to_f

      return 0 if total.nil? || total.zero?

      [(processed / total * 100).round(2), 100].min
    end

    def update_progress(processed:, total:, details: nil)
      progress_data = {
        'progress' => {
          'processed' => processed,
          'total' => total,
          'percentage' => processed.to_f / total * 100,
          'updated_at' => Time.current.iso8601
        }
      }

      progress_data['progress']['details'] = details if details.present?

      update!(metadata: metadata.merge(progress_data))
    end

    def mark_started!(started_time = Time.current)
      update!(
        status: 'in_progress',
        started_at: started_time,
        metadata: metadata.merge('started_at' => started_time.iso8601)
      )
    end

    def mark_completed!(result_data = nil)
      completed_time = Time.current
      duration_seconds = started_at ? (completed_time - started_at).round(2) : nil
      
      update_attrs = {
        status: 'completed',
        completed_at: completed_time,
        metadata: metadata.merge(
          'completed_at' => completed_time.iso8601,
          'duration_seconds' => duration_seconds
        )
      }

      update_attrs[:result] = result_data if result_data.present?
      update!(update_attrs)
    end

    def mark_failed!(error, error_details = nil)
      failed_time = Time.current
      update_attrs = {
        status: 'failed',
        completed_at: failed_time,
        error_message: error.to_s,
        metadata: metadata.merge(
          'failed_at' => failed_time.iso8601,
          'duration_seconds' => duration&.round(2)
        )
      }

      if error_details.present?
        update_attrs[:metadata] = update_attrs[:metadata].merge('error_details' => error_details)
      end

      update!(update_attrs)
    end

    def mark_cancelled!(reason = nil)
      cancelled_time = Time.current
      update_attrs = {
        status: 'cancelled',
        completed_at: cancelled_time,
        metadata: metadata.merge(
          'cancelled_at' => cancelled_time.iso8601,
          'duration_seconds' => duration&.round(2)
        )
      }

      update_attrs[:metadata] = update_attrs[:metadata].merge('cancellation_reason' => reason) if reason.present?

      update!(update_attrs)
    end

    # Class methods
    def self.create_for_seed_planting(source:, user: nil, metadata: {})
      create!(
        planting_type: 'seed',
        source: source,
        user: user,
        metadata: {
          'planting_source' => source,
          'created_at' => Time.current.iso8601
        }.merge(metadata)
      )
    end

    def self.cleanup_old_plantings(older_than: 30.days)
      terminal.where('completed_at < ?', older_than.ago).destroy_all
    end

    private

    def status_changed_to_in_progress?
      status_changed? && in_progress?
    end

    def status_changed_to_terminal?
      status_changed? && terminal?
    end

    def set_started_at
      self.started_at ||= Time.current
    end

    def set_completed_at
      self.completed_at ||= Time.current if terminal?
    end

    def completed_at_presence_for_terminal_states
      return unless terminal? && completed_at.blank?

      errors.add(:completed_at, 'must be present for completed, failed, or cancelled plantings')
    end

    def error_message_presence_for_failed_state
      return unless failed? && error_message.blank?

      errors.add(:error_message, 'must be present for failed plantings')
    end
  end
end
