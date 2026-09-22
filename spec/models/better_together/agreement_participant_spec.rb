# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AgreementParticipant do
  subject(:participant_record) { create(:better_together_agreement_participant, agreement:, participant: person) }

  let(:agreement) { create(:better_together_agreement) }
  let(:person) { create(:better_together_person) }
  let(:robot) { create(:robot) }

  it { is_expected.to belong_to(:agreement).class_name('BetterTogether::Agreement') }
  it { is_expected.to belong_to(:participant) }

  it 'has a valid factory' do
    expect(participant_record).to be_valid
  end

  it 'captures immutable agreement acceptance audit details on create', :aggregate_failures do
    agreement.update!(title: 'Original Title')

    participant = create(
      :better_together_agreement_participant,
      agreement:,
      participant: person,
      acceptance_method: :agreement_review,
      audit_context: { 'source_path' => '/en/agreements/status' }
    )

    original_digest = participant.agreement_content_digest
    original_title = participant.agreement_title_snapshot
    original_revision = participant.agreement_updated_at_snapshot

    agreement.update!(title: 'Updated Title')
    participant.reload

    expect(participant.agreement_title_snapshot).to eq(original_title)
    expect(participant.agreement_content_digest).to eq(original_digest)
    expect(participant.agreement_updated_at_snapshot).to eq(original_revision)
    expect(participant.audit_context).to include('source_path' => '/en/agreements/status')
  end

  it 'refreshes the acceptance snapshot when the participant re-accepts an updated agreement', :aggregate_failures do
    agreement.update!(title: 'Original Title', requires_reacceptance: true)
    participant = create(:better_together_agreement_participant, agreement:, participant: person, accepted_at: 1.day.ago)

    original_digest = participant.agreement_content_digest

    agreement.update!(title: 'Updated Title')
    participant.update!(accepted_at: Time.current, acceptance_method: :agreement_review)
    participant.reload

    expect(participant.agreement_title_snapshot).to eq('Updated Title')
    expect(participant.agreement_content_digest).not_to eq(original_digest)
    expect(participant).to be_current_for_agreement
    expect(participant).not_to be_stale_for_agreement
  end

  it 'falls back to a humanized identifier when the agreement title is blank' do
    agreement.update!(title: nil)

    participant = create(:better_together_agreement_participant, agreement:, participant: person)

    expect(participant.agreement_title_snapshot).to eq(agreement.identifier.to_s.humanize)
  end

  it 'backfills the legacy person association when the participant is a person' do
    participant = create(:better_together_agreement_participant, agreement:, participant: person)

    expect(participant.person).to eq(person)
    expect(participant.participant).to eq(person)
  end

  it 'supports robot participants without populating the legacy person column' do
    participant = create(:better_together_agreement_participant, agreement:, participant: robot)

    expect(participant.participant).to eq(robot)
    expect(participant.person).to be_nil
  end
end
