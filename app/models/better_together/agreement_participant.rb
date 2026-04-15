# frozen_string_literal: true

module BetterTogether
  # Joins governed agents to agreements they have accepted, preserving
  # compatibility with the original person-bound participation model.
  class AgreementParticipant < ApplicationRecord
    belongs_to :agreement, class_name: 'BetterTogether::Agreement'
    belongs_to :participant, polymorphic: true
    belongs_to :person, class_name: 'BetterTogether::Person', optional: true

    enum :acceptance_method, {
      legacy: 'legacy',
      sign_up: 'sign_up',
      agreement_review: 'agreement_review',
      api: 'api',
      system: 'system'
    }, validate: true

    scope :accepted, -> { where.not(accepted_at: nil) }
    scope :for_participant, lambda { |participant|
      return none unless participant.present?

      where(participant:)
    }

    before_validation :capture_acceptance_audit, if: :refresh_acceptance_audit?
    before_validation :sync_legacy_person_and_participant!

    validates :acceptance_method, presence: true
    validates :participant_type, :participant_id, presence: true
    validates :agreement_id, uniqueness: { scope: %i[participant_type participant_id] }
    validates :agreement_identifier_snapshot, :agreement_title_snapshot, :agreement_updated_at_snapshot,
              :agreement_content_digest, presence: true

    def current_for_agreement?
      return false unless accepted_at.present?
      return true unless agreement&.requires_reacceptance?

      agreement_content_digest == agreement.acceptance_content_digest
    end

    def stale_for_agreement?
      accepted_at.present? && !current_for_agreement?
    end

    private

    def refresh_acceptance_audit?
      new_record? || will_save_change_to_accepted_at? || will_save_change_to_acceptance_method?
    end

    def capture_acceptance_audit
      return unless agreement

      assign_attributes(refresh_acceptance_audit_attributes)
      self.audit_context = normalized_audit_context
    end

    def refresh_acceptance_audit_attributes
      return default_acceptance_audit_attributes if new_record?

      {
        acceptance_method: acceptance_method_value,
        agreement_identifier_snapshot: agreement.identifier.to_s,
        agreement_title_snapshot: agreement_title_snapshot_value(force_refresh: true),
        agreement_updated_at_snapshot: agreement_updated_at_snapshot_value(force_refresh: true),
        agreement_content_digest: agreement.acceptance_content_digest
      }
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

    def agreement_title_snapshot_value(force_refresh: false)
      return agreement.title.presence || agreement.identifier.to_s.humanize if force_refresh

      agreement_title_snapshot.presence || agreement.title.presence || agreement.identifier.to_s.humanize
    end

    def agreement_updated_at_snapshot_value(force_refresh: false)
      return agreement.updated_at || Time.current if force_refresh

      agreement_updated_at_snapshot || agreement.updated_at || Time.current
    end

    def agreement_content_digest_value
      agreement_content_digest.presence || agreement.acceptance_content_digest
    end

    def sync_legacy_person_and_participant!
      self.participant ||= person if person.present?
      self.person ||= participant if participant.is_a?(BetterTogether::Person)
    end
  end
end
