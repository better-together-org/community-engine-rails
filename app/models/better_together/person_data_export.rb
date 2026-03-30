# frozen_string_literal: true

module BetterTogether
  # Stores generated account-data export requests and attached export archives.
  class PersonDataExport < ApplicationRecord
    self.table_name = 'better_together_person_data_exports'

    STATUS_VALUES = {
      pending: 'pending',
      processing: 'processing',
      completed: 'completed',
      failed: 'failed'
    }.freeze

    belongs_to :person, class_name: 'BetterTogether::Person', inverse_of: :person_data_exports
    has_one_attached :export_file, dependent: :purge_later

    enum :status, STATUS_VALUES, default: :pending, validate: true

    validates :format, presence: true, inclusion: { in: %w[json] }
    validates :person_id, presence: true
    validates :requested_at, presence: true

    scope :latest_first, -> { order(requested_at: :desc, created_at: :desc) }
    scope :active, -> { where(status: %w[pending processing]) }

    after_create_commit :enqueue_generation

    def filename
      "person-data-export-#{person_id}-#{requested_at.to_date.iso8601}.json"
    end

    def mark_processing!
      update!(status: :processing, started_at: Time.current, error_message: nil)
    end

    def mark_completed!
      update!(status: :completed, completed_at: Time.current, error_message: nil)
    end

    def mark_failed!(message)
      update!(status: :failed, completed_at: Time.current, error_message: message)
    end

    private

    def enqueue_generation
      BetterTogether::GeneratePersonDataExportJob.perform_later(id)
    end
  end
end
