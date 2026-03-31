# frozen_string_literal: true

class AddAcceptanceAuditFieldsToAgreementParticipants < ActiveRecord::Migration[7.1]
  def up
    return unless table_exists?(:better_together_agreement_participants)

    add_acceptance_audit_columns
    backfill_acceptance_audit_fields
    enforce_acceptance_audit_constraints
  end

  def down
    return unless table_exists?(:better_together_agreement_participants)

    remove_acceptance_audit_columns
  end

  private

  def add_acceptance_audit_columns
    add_column_if_missing :acceptance_method, :string
    add_column_if_missing :agreement_identifier_snapshot, :string
    add_column_if_missing :agreement_title_snapshot, :string
    add_column_if_missing :agreement_updated_at_snapshot, :datetime
    add_column_if_missing :agreement_content_digest, :string
    add_column_if_missing :audit_context, :jsonb, default: {}, null: false
  end

  def backfill_acceptance_audit_fields
    BetterTogether::AgreementParticipant.reset_column_information
    BetterTogether::Agreement.reset_column_information

    say_with_time 'Backfilling agreement acceptance audit fields' do
      BetterTogether::AgreementParticipant.includes(:agreement).find_each do |participant|
        agreement = participant.agreement
        next unless agreement

        participant.update_columns(backfilled_acceptance_attributes(participant, agreement))
      end
    end
  end

  def backfilled_acceptance_attributes(participant, agreement)
    {
      acceptance_method: participant[:acceptance_method].presence || 'legacy',
      agreement_identifier_snapshot: participant[:agreement_identifier_snapshot].presence || agreement.identifier.to_s,
      agreement_title_snapshot: participant[:agreement_title_snapshot].presence || agreement.title.to_s,
      agreement_updated_at_snapshot: participant[:agreement_updated_at_snapshot] || participant_snapshot_time(participant, agreement),
      agreement_content_digest: participant[:agreement_content_digest].presence || agreement.acceptance_content_digest,
      audit_context: (participant[:audit_context].presence || {}).merge('backfilled' => true)
    }
  end

  def participant_snapshot_time(participant, agreement)
    agreement.updated_at || participant.accepted_at || participant.created_at || Time.current
  end

  def enforce_acceptance_audit_constraints
    change_column_default :better_together_agreement_participants, :acceptance_method, 'agreement_review'

    %i[
      acceptance_method
      agreement_identifier_snapshot
      agreement_title_snapshot
      agreement_updated_at_snapshot
      agreement_content_digest
    ].each do |column_name|
      change_column_null :better_together_agreement_participants, column_name, false
    end
  end

  def remove_acceptance_audit_columns
    %i[
      audit_context
      agreement_content_digest
      agreement_updated_at_snapshot
      agreement_title_snapshot
      agreement_identifier_snapshot
      acceptance_method
    ].each do |column_name|
      remove_column_if_present(column_name)
    end
  end

  def add_column_if_missing(column_name, type, **)
    return if column_exists?(:better_together_agreement_participants, column_name)

    add_column :better_together_agreement_participants, column_name, type, **
  end

  def remove_column_if_present(column_name)
    return unless column_exists?(:better_together_agreement_participants, column_name)

    remove_column :better_together_agreement_participants, column_name
  end
end
