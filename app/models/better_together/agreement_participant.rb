# frozen_string_literal: true

module BetterTogether
  # joins people to agreements they have accepted
  class AgreementParticipant < ApplicationRecord
    belongs_to :agreement, class_name: 'BetterTogether::Agreement'
    belongs_to :person, class_name: 'BetterTogether::Person'

    enum :acceptance_method, {
      legacy: 'legacy',
      sign_up: 'sign_up',
      agreement_review: 'agreement_review',
      api: 'api',
      system: 'system'
    }, validate: true

    before_validation :capture_acceptance_audit, on: :create

    validates :acceptance_method, presence: true
    validates :agreement_id, uniqueness: { scope: :person_id }
    validates :agreement_identifier_snapshot, :agreement_title_snapshot, :agreement_updated_at_snapshot,
              :agreement_content_digest, presence: true

    private

    def capture_acceptance_audit
      return unless agreement

      assign_attributes(default_acceptance_audit_attributes)
      self.audit_context = normalized_audit_context
    end

    def default_acceptance_audit_attributes
      {
        acceptance_method: acceptance_method_value,
        agreement_identifier_snapshot: agreement_identifier_snapshot_value,
        agreement_title_snapshot: agreement_title_snapshot_value,
        agreement_updated_at_snapshot: agreement_updated_at_snapshot_value,
        agreement_content_digest: agreement_content_digest_value
      }
    end

    def normalized_audit_context
      (audit_context.presence || {}).deep_stringify_keys
    end

    def acceptance_method_value
      acceptance_method.presence || 'agreement_review'
    end

    def agreement_identifier_snapshot_value
      agreement_identifier_snapshot.presence || agreement.identifier.to_s
    end

    def agreement_title_snapshot_value
      agreement_title_snapshot.presence || agreement.title.presence || agreement.identifier.to_s.humanize
    end

    def agreement_updated_at_snapshot_value
      agreement_updated_at_snapshot || agreement.updated_at || Time.current
    end

    def agreement_content_digest_value
      agreement_content_digest.presence || agreement.acceptance_content_digest
    end
  end
end
