# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonDeletionExecutor do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:reviewer) { create(:better_together_person) }
  let(:deletion_request) { create(:better_together_person_deletion_request, person:) }
  let(:retained_authorship_count) { BetterTogether::Authorship.where(author_id: person.id).count }

  before do
    create(:better_together_person_data_export, person:)

    platform = create(:better_together_platform)
    page = create(:better_together_page, creator: person, platform:)

    BetterTogether::Authorship.create!(author: person, authorable: page)

    conversation = BetterTogether::Conversation.create!(
      creator: person,
      title: 'Deletion executor test',
      participant_ids: [person.id]
    )
    BetterTogether::Message.create!(conversation:, sender: person, content: 'Retained message')
  end

  it 'destroys private records while anonymizing the retained person graph' do
    audit = described_class.call(person_deletion_request: deletion_request, reviewed_by: reviewer)

    expect(BetterTogether::User.exists?(user.id)).to be(false)
    expect(BetterTogether::PersonDataExport.where(person_id: person.id)).to be_empty
    expect(BetterTogether::Message.where(sender_id: person.id).count).to eq(1)
    expect(BetterTogether::Authorship.where(author_id: person.id).count).to eq(retained_authorship_count)

    person.reload
    deletion_request.reload

    expect(person.anonymized_at).to be_present
    expect(person.deleted_at).to be_present
    expect(person.identifier).to start_with('deleted-person-')
    expect(person.contact_detail).to be_nil
    expect(deletion_request).to be_approved
    expect(deletion_request.requested_reason).to be_nil
    expect(audit).to be_completed
    expect(audit.execution_snapshot.fetch('destroyed_entries')).not_to be_empty
  end
end
