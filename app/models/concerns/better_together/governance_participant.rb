# frozen_string_literal: true

module BetterTogether
  # Reverse associations for safety and deletion-review governance roles.
  module GovernanceParticipant
    extend ActiveSupport::Concern

    # rubocop:disable Metrics/BlockLength
    included do
      has_many :authored_safety_notes,
               foreign_key: :author_id,
               class_name: 'BetterTogether::Safety::Note',
               inverse_of: :author
      has_many :acted_safety_actions,
               foreign_key: :actor_id,
               class_name: 'BetterTogether::Safety::Action',
               inverse_of: :actor
      has_many :approved_safety_actions,
               foreign_key: :approved_by_id,
               class_name: 'BetterTogether::Safety::Action',
               inverse_of: :approved_by
      has_many :created_safety_agreements,
               foreign_key: :created_by_id,
               class_name: 'BetterTogether::Safety::Agreement',
               inverse_of: :created_by
      has_many :assigned_safety_cases,
               foreign_key: :assigned_reviewer_id,
               class_name: 'BetterTogether::Safety::Case',
               inverse_of: :assigned_reviewer
      has_many :reviewed_person_deletion_requests,
               foreign_key: :reviewed_by_id,
               class_name: 'BetterTogether::PersonDeletionRequest',
               inverse_of: :reviewed_by
      has_many :reviewed_person_purge_audits,
               foreign_key: :reviewed_by_id,
               class_name: 'BetterTogether::PersonPurgeAudit',
               inverse_of: :reviewed_by
    end
    # rubocop:enable Metrics/BlockLength
  end
end
