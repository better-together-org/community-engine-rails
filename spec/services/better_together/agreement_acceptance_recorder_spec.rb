# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AgreementAcceptanceRecorder, type: :service do
  let(:agreement) { create(:better_together_agreement) }
  let(:person) { create(:better_together_person) }

  let(:mock_request) do
    instance_double(
      ActionDispatch::Request,
      request_id: 'req-abc-123',
      fullpath: '/agreements/123/accept'
    )
  end

  describe '.record!' do
    it 'creates an AgreementParticipant record' do
      expect do
        described_class.record!(agreement: agreement, acceptance_method: 'agreement_review', participant: person)
      end.to change(BetterTogether::AgreementParticipant, :count).by(1)
    end

    it 'returns the agreement participant' do
      result = described_class.record!(
        agreement: agreement,
        acceptance_method: 'agreement_review',
        participant: person
      )

      expect(result).to be_a(BetterTogether::AgreementParticipant)
      expect(result).to be_persisted
    end

    it 'sets the acceptance_method on the participant' do
      result = described_class.record!(
        agreement: agreement,
        acceptance_method: 'agreement_review',
        participant: person
      )

      expect(result.acceptance_method).to eq('agreement_review')
    end

    it 'sets the accepted_at timestamp' do
      frozen_time = Time.zone.parse('2026-01-15 10:00:00')
      result = described_class.record!(
        agreement: agreement,
        acceptance_method: 'agreement_review',
        participant: person,
        accepted_at: frozen_time
      )

      expect(result.accepted_at).to be_within(1.second).of(frozen_time)
    end
  end

  describe 'audit context normalization' do
    it 'captures locale in the audit context' do
      allow(I18n).to receive(:locale).and_return(:fr)
      result = described_class.record!(
        agreement: agreement,
        acceptance_method: 'agreement_review',
        participant: person,
        context: {}
      )

      expect(result.audit_context['locale']).to eq('fr')
    end

    it 'captures request_id when a request object is provided' do
      result = described_class.record!(
        agreement: agreement,
        acceptance_method: 'agreement_review',
        participant: person,
        context: { request: mock_request }
      )

      expect(result.audit_context['request_id']).to eq('req-abc-123')
    end

    it 'captures source_path when a request object is provided' do
      result = described_class.record!(
        agreement: agreement,
        acceptance_method: 'agreement_review',
        participant: person,
        context: { request: mock_request }
      )

      expect(result.audit_context['source_path']).to eq('/agreements/123/accept')
    end

    it 'does not store the raw request object in the audit context' do
      result = described_class.record!(
        agreement: agreement,
        acceptance_method: 'agreement_review',
        participant: person,
        context: { request: mock_request }
      )

      expect(result.audit_context).not_to have_key('request')
    end

    it 'omits nil context keys from the audit context' do
      null_request = instance_double(ActionDispatch::Request, request_id: nil, fullpath: nil)
      result = described_class.record!(
        agreement: agreement,
        acceptance_method: 'agreement_review',
        participant: person,
        context: { request: null_request }
      )

      expect(result.audit_context).not_to have_key('request_id')
      expect(result.audit_context).not_to have_key('source_path')
    end

    it 'preserves additional non-request context keys' do
      result = described_class.record!(
        agreement: agreement,
        acceptance_method: 'agreement_review',
        participant: person,
        context: { channel: 'api', version: '2' }
      )

      expect(result.audit_context['channel']).to eq('api')
      expect(result.audit_context['version']).to eq('2')
    end
  end

  describe 'idempotent re-acceptance' do
    it 'updates an existing participant record rather than creating a duplicate' do
      described_class.record!(agreement: agreement, acceptance_method: 'agreement_review', participant: person)

      expect do
        described_class.record!(
          agreement: agreement,
          acceptance_method: 'api',
          participant: person
        )
      end.not_to change(BetterTogether::AgreementParticipant, :count)
    end

    it 'updates the acceptance_method on re-acceptance' do
      described_class.record!(agreement: agreement, acceptance_method: 'agreement_review', participant: person)
      result = described_class.record!(
        agreement: agreement,
        acceptance_method: 'api',
        participant: person
      )

      expect(result.acceptance_method).to eq('api')
    end
  end

  describe 'participant keyword alias' do
    it 'accepts person: as a keyword alias for participant:' do
      result = described_class.record!(
        agreement: agreement,
        acceptance_method: 'agreement_review',
        person: person
      )

      expect(result.participant).to eq(person)
    end
  end
end
