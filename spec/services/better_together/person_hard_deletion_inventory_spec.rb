# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonHardDeletionInventory do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let!(:owned_community) { create(:better_together_community, creator: person, protected: true) }

  before do
    person.update!(community: owned_community)
    create(:better_together_person_data_export, person:)
    create(:better_together_person_deletion_request, person:)
    create(:better_together_calendar, creator: person, community: owned_community, protected: true)
    create(:better_together_person_community_membership, member: person, joinable: owned_community)

    platform = create(:better_together_platform)
    create(:better_together_person_platform_membership, member: person, joinable: platform)
    page = create(:better_together_page, creator: person, platform:)
    BetterTogether::Authorship.create!(author: person, authorable: page)

    conversation = BetterTogether::Conversation.create!(
      creator: person,
      title: 'Hard deletion inventory test',
      participant_ids: [person.id]
    )
    BetterTogether::Message.create!(conversation:, sender: person, content: 'Delete this message')
  end

  it 'marks mixed-policy retain and anonymize entries for destruction while direct-deleting memberships' do
    inventory = described_class.call(person:)
    entries = inventory.fetch(:entries).index_by { |entry| entry.fetch(:key) }

    expect(inventory.fetch(:deletion_mode)).to eq('hard_delete')
    expect(entries.fetch('user').fetch(:action)).to eq('destroy')
    expect(entries.fetch('person').fetch(:action)).to eq('destroy')
    expect(entries.fetch('BetterTogether::Message#sender').fetch(:action)).to eq('destroy')
    expect(entries.fetch('BetterTogether::Message#sender').fetch(:original_action)).to eq('anonymize')
    expect(entries.fetch('BetterTogether::PersonDeletionRequest#person').fetch(:action)).to eq('destroy')
    expect(entries.fetch('BetterTogether::PersonDeletionRequest#person').fetch(:original_action)).to eq('retain')
    expect(entries.fetch('BetterTogether::PersonCommunityMembership#member').fetch(:action)).to eq('delete')
    expect(entries.fetch('BetterTogether::PersonPlatformMembership#member').fetch(:action)).to eq('delete')
    expect(entries.fetch('person.owned_primary_community').fetch(:ids)).to eq([owned_community.id.to_s])
  end
end
