# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonHardDeletionInventory do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }

  before do
    create(:better_together_person_data_export, person:)
    create(:better_together_person_deletion_request, person:)

    platform = create(:better_together_platform)
    page = create(:better_together_page, creator: person, platform:)
    BetterTogether::Authorship.create!(author: person, authorable: page)

    conversation = BetterTogether::Conversation.create!(
      creator: person,
      title: 'Hard deletion inventory test',
      participant_ids: [person.id]
    )
    BetterTogether::Message.create!(conversation:, sender: person, content: 'Delete this message')
  end

  it 'marks mixed-policy retain and anonymize entries for destruction' do
    inventory = described_class.call(person:)
    entries = inventory.fetch(:entries).index_by { |entry| entry.fetch(:key) }

    expect(inventory.fetch(:deletion_mode)).to eq('hard_delete')
    expect(entries.fetch('user').fetch(:action)).to eq('destroy')
    expect(entries.fetch('person').fetch(:action)).to eq('destroy')
    expect(entries.fetch('BetterTogether::Message#sender').fetch(:action)).to eq('destroy')
    expect(entries.fetch('BetterTogether::Message#sender').fetch(:original_action)).to eq('anonymize')
    expect(entries.fetch('BetterTogether::PersonDeletionRequest#person').fetch(:action)).to eq('destroy')
    expect(entries.fetch('BetterTogether::PersonDeletionRequest#person').fetch(:original_action)).to eq('retain')
  end
end
