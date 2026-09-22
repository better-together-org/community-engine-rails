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
    # Deliberately not PlatformScoped: platform_id here is a permanent
    # audit-trail snapshot, captured explicitly by the purge executor before
    # the purged person's platform associations are nullified — it must never
    # be silently reassigned to Current.platform on create/update the way
    # PlatformScoped's auto-assignment would. Mirrors the reasoning on
    # PersonLinkedSeed#source_platform.
    belongs_to :platform,
               class_name: 'BetterTogether::Platform',
               optional: true

    enum :status, STATUS_VALUES, validate: true

    validates :status, presence: true
    validates :inventory_snapshot, presence: true
    validates :execution_snapshot, presence: true

    before_update do
      # Allow exactly one status transition: running → completed or running → failed.
      # After reaching a terminal state the record is fully immutable.
      allowed = status_was == 'running' && %w[completed failed].include?(status)
      raise ActiveRecord::ReadOnlyRecord, 'PersonPurgeAudit records are immutable after completion' unless allowed
    end
    before_destroy { raise ActiveRecord::ReadOnlyRecord, 'PersonPurgeAudit records are immutable' }
  end
end
