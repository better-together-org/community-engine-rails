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
end
