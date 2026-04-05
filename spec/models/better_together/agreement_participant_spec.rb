# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AgreementParticipant do
  subject(:participant) { create(:better_together_agreement_participant, agreement:, person:) }

  let(:agreement) { create(:better_together_agreement) }
  let(:person) { create(:better_together_person) }

  it { is_expected.to belong_to(:agreement).class_name('BetterTogether::Agreement') }
  it { is_expected.to belong_to(:person).class_name('BetterTogether::Person') }

  it 'has a valid factory' do
    expect(participant).to be_valid
  end

  it 'captures immutable agreement acceptance audit details on create', :aggregate_failures do
    agreement.update!(title: 'Original Title')

    participant = create(
      :better_together_agreement_participant,
      agreement:,
      person:,
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

  it 'falls back to a humanized identifier when the agreement title is blank' do
    agreement.update!(title: nil)

    participant = create(:better_together_agreement_participant, agreement:, person:)

    expect(participant.agreement_title_snapshot).to eq(agreement.identifier.to_s.humanize)
  end
end
