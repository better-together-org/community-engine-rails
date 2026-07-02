# frozen_string_literal: true

module BetterTogether
  # AgentJobResult records the output of a borgberry fleet job.
  # Implements the Seedable concern so job results are GDPR-portable
  # and federable via CE Seed infrastructure.
  class AgentJobResult < ApplicationRecord
    JOB_STATUSES = %w[pending running completed failed].freeze

    belongs_to :fleet_node, class_name: 'BetterTogether::Fleet::Node', optional: true
    belongs_to :submitter, polymorphic: true, optional: true

    validates :job_id, presence: true, uniqueness: true
    validates :job_type, :source_system, presence: true
    validates :status, inclusion: { in: JOB_STATUSES }

    scope :completed, -> { where(status: 'completed') }
    scope :failed, -> { where(status: 'failed') }
    scope :for_node, ->(node_id) { where(node_id: node_id) }

    def duration_s
      return nil unless started_at && completed_at

      (completed_at - started_at).to_f
    end

    def success?
      status == 'completed'
    end

    def to_s
      "#{job_type}:#{job_id}"
    end
  end
end
