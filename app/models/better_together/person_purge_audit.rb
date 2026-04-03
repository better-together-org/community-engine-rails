# frozen_string_literal: true

module BetterTogether
  # Immutable audit record for person deletion and hard-delete executions.
  class PersonPurgeAudit < ApplicationRecord
    self.table_name = 'better_together_person_purge_audits'

    STATUS_VALUES = {
      running: 'running',
      completed: 'completed',
      failed: 'failed'
    }.freeze

    belongs_to :person,
               class_name: 'BetterTogether::Person',
               optional: true,
               inverse_of: :person_purge_audits
    belongs_to :person_deletion_request,
               class_name: 'BetterTogether::PersonDeletionRequest',
               optional: true,
               inverse_of: :person_purge_audits
    belongs_to :reviewed_by,
               class_name: 'BetterTogether::Person',
               optional: true,
               inverse_of: :reviewed_person_purge_audits

    enum :status, STATUS_VALUES, validate: true

    validates :status, presence: true
    validates :inventory_snapshot, presence: true
    validates :execution_snapshot, presence: true
  end
end
