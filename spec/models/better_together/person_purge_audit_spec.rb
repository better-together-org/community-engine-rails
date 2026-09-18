# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonPurgeAudit do
  let(:person) { create(:better_together_person) }
  let(:deletion_request) { create(:better_together_person_deletion_request, person: person) }

  describe 'immutability contract' do
    it 'can be created in running state' do
      audit = create(:better_together_person_purge_audit, person: person, person_deletion_request: deletion_request)
      expect(audit).to be_persisted
      expect(audit.status).to eq('running')
    end

    it 'allows a single running → completed transition' do
      audit = create(:better_together_person_purge_audit, person: person, person_deletion_request: deletion_request)
      expect do
        audit.update!(status: 'completed', completed_at: Time.current)
      end.not_to raise_error
      expect(audit.reload.status).to eq('completed')
    end

    it 'allows a single running → failed transition' do
      audit = create(:better_together_person_purge_audit, person: person, person_deletion_request: deletion_request)
      expect do
        audit.update!(status: 'failed', error_message: 'something went wrong', failed_at: Time.current)
      end.not_to raise_error
      expect(audit.reload.status).to eq('failed')
    end

    it 'blocks any update to a completed record' do
      audit = create(:better_together_person_purge_audit, :completed, person: person,
                                                                      person_deletion_request: deletion_request)
      expect do
        audit.update!(error_message: 'tampering attempt')
      end.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'blocks any update to a failed record' do
      audit = create(:better_together_person_purge_audit, :failed, person: person,
                                                                   person_deletion_request: deletion_request)
      expect do
        audit.update!(status: 'completed')
      end.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'blocks direct running → running update (no-op mutation attempt)' do
      audit = create(:better_together_person_purge_audit, person: person, person_deletion_request: deletion_request)
      expect do
        audit.update!(person_name_snapshot: 'Tampered Name')
      end.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'prevents destruction of any purge audit record' do
      audit = create(:better_together_person_purge_audit, person: person, person_deletion_request: deletion_request)
      expect do
        audit.destroy!
      end.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe 'status enum' do
    it 'defaults to running' do
      audit = create(:better_together_person_purge_audit, person: person, person_deletion_request: deletion_request)
      expect(audit.status).to eq('running')
    end

    it 'validates status inclusion' do
      audit = build(:better_together_person_purge_audit, person: person,
                                                         person_deletion_request: deletion_request,
                                                         status: 'invalid')
      expect(audit).not_to be_valid
    end
  end
end
