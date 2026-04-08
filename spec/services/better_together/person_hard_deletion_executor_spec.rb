# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonHardDeletionExecutor do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:reviewer) { create(:better_together_person) }

  before do
    create(:better_together_person_data_export, person:)
    create(:better_together_person_deletion_request, person:)

    platform = create(:better_together_platform)
    page = create(:better_together_page, creator: person, platform:)
    BetterTogether::Authorship.create!(author: person, authorable: page)

    conversation = BetterTogether::Conversation.create!(
      creator: person,
      title: 'Hard deletion executor test',
      participant_ids: [person.id]
    )
    BetterTogether::Message.create!(conversation:, sender: person, content: 'Delete this message')
  end

  it 'fully destroys the user, person, and retained graph while preserving the audit' do
    user_id = user.id
    person_id = person.id
    message_ids = BetterTogether::Message.where(sender_id: person.id).pluck(:id)
    authorship_ids = BetterTogether::Authorship.where(author_type: 'BetterTogether::Person', author_id: person.id)
                                               .pluck(:id)

    audit = described_class.call(person:, reviewed_by: reviewer, reason: 'prelaunch bot cleanup')

    expect(BetterTogether::User.exists?(user_id)).to be(false)
    expect(BetterTogether::Person.exists?(person_id)).to be(false)
    expect(BetterTogether::PersonDataExport.where(person_id: person_id)).to be_empty
    expect(BetterTogether::PersonDeletionRequest.where(person_id: person_id)).to be_empty
    expect(BetterTogether::Message.where(id: message_ids)).to be_empty
    expect(BetterTogether::Authorship.where(id: authorship_ids)).to be_empty

    expect(audit).to be_completed
    expect(audit.person_id).to be_nil
    expect(audit.person_deletion_request_id).to be_nil
    expect(audit.execution_snapshot.fetch('deletion_mode')).to eq('hard_delete')
    expect(audit.execution_snapshot.fetch('destroyed_entries')).not_to be_empty
  end
end
