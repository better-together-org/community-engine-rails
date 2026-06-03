# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonHardDeletionExecutor do
  include ActiveJob::TestHelper

  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:reviewer) { create(:better_together_person) }
  let!(:owned_community) { create(:better_together_community, creator: person, protected: true) }
  let!(:platform) { create(:better_together_platform) }
  let!(:deletion_request) { create(:better_together_person_deletion_request, person:) }

  before do
    person.update!(community: owned_community)
    create(:better_together_person_data_export, person:)
    create(:better_together_calendar, creator: person, community: owned_community, protected: true)
    create(:better_together_person_community_membership, member: person, joinable: owned_community)
    create(:better_together_person_platform_membership, member: person, joinable: platform)

    page = create(:better_together_page, creator: person, platform:)
    BetterTogether::Authorship.create!(author: person, authorable: page)

    conversation = BetterTogether::Conversation.create!(
      creator: person,
      title: 'Hard deletion executor test',
      participant_ids: [person.id]
    )
    BetterTogether::Message.create!(conversation:, sender: person, content: 'Delete this message')
  end

  it 'fully destroys the user, person, memberships, and owned community while preserving the audit' do
    user_id = user.id
    person_id = person.id
    community_id = owned_community.id
    message_ids = BetterTogether::Message.where(sender_id: person.id).pluck(:id)
    authorship_ids = BetterTogether::Authorship.where(author_type: 'BetterTogether::Person', author_id: person.id)
                                               .pluck(:id)
    membership_ids = BetterTogether::PersonCommunityMembership.where(member_id: person.id).pluck(:id)
    platform_membership_ids = BetterTogether::PersonPlatformMembership.where(member_id: person.id).pluck(:id)
    clear_enqueued_jobs

    audit = described_class.call(
      person:,
      person_deletion_request: deletion_request,
      reviewed_by: reviewer,
      reason: 'prelaunch bot cleanup'
    )

    expect(BetterTogether::User.exists?(user_id)).to be(false)
    expect(BetterTogether::Person.exists?(person_id)).to be(false)
    expect(BetterTogether::Community.exists?(community_id)).to be(false)
    expect(BetterTogether::PersonDataExport.where(person_id: person_id)).to be_empty
    expect(BetterTogether::PersonDeletionRequest.where(person_id: person_id)).to be_empty
    expect(BetterTogether::PersonCommunityMembership.where(id: membership_ids)).to be_empty
    expect(BetterTogether::PersonPlatformMembership.where(id: platform_membership_ids)).to be_empty
    expect(BetterTogether::Message.where(id: message_ids)).to be_empty
    expect(BetterTogether::Authorship.where(id: authorship_ids)).to be_empty

    expect(audit).to be_completed
    expect(audit.person_id).to be_nil
    expect(audit.person_deletion_request_id).to be_nil
    expect(audit.execution_snapshot.fetch('deletion_mode')).to eq('hard_delete')
    expect(audit.execution_snapshot.fetch('destroyed_entries')).not_to be_empty
    expect(audit.execution_snapshot.fetch('verification').values).to all(include('completed' => true))
    expect(enqueued_jobs.map { |job| job[:job] }).not_to include(BetterTogether::CleanupNotificationsJob)
  end
end
