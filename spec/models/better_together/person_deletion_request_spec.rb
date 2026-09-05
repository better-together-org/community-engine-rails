# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonDeletionRequest do
  it 'prevents more than one pending request per person' do
    person = create(:better_together_person)
    create(:better_together_person_deletion_request, person: person)

    duplicate = build(:better_together_person_deletion_request, person: person)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:base]).to include('already has a pending deletion request')
  end

  it 'can be cancelled' do
    request = create(:better_together_person_deletion_request)

    request.cancel!

    expect(request).to be_cancelled
    expect(request.resolved_at).to be_present
  end

  it 'can be approved with reviewer details' do
    reviewer = create(:better_together_person)
    request = create(:better_together_person_deletion_request)

    request.approve!(reviewed_by: reviewer, reviewer_notes: 'Identity confirmed, approved.')

    expect(request).to be_approved
    expect(request.reviewed_by).to eq(reviewer)
    expect(request.reviewer_notes).to eq('Identity confirmed, approved.')
    expect(request.resolved_at).to be_present
  end

  it 'can be rejected with reviewer details' do
    reviewer = create(:better_together_person)
    request = create(:better_together_person_deletion_request)

    request.reject!(reviewed_by: reviewer, reviewer_notes: 'Insufficient reason provided.')

    expect(request).to be_rejected
    expect(request.reviewed_by).to eq(reviewer)
    expect(request.reviewer_notes).to eq('Insufficient reason provided.')
    expect(request.resolved_at).to be_present
  end

  describe '.active' do
    it 'returns only pending requests' do
      pending_req = create(:better_together_person_deletion_request)
      cancelled_req = create(:better_together_person_deletion_request)
      cancelled_req.cancel!

      expect(described_class.active).to include(pending_req)
      expect(described_class.active).not_to include(cancelled_req)
    end
  end

  describe '.latest_first' do
    it 'orders by requested_at descending' do
      older = create(:better_together_person_deletion_request, requested_at: 2.days.ago)
      newer = create(:better_together_person_deletion_request, requested_at: 1.day.ago)

      result = described_class.latest_first.to_a
      expect(result.index(newer)).to be < result.index(older)
    end
  end
end
