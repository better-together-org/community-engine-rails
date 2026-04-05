# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonDeletionInventory do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }

  before do
    create(:better_together_person_data_export, person:)

    conversation = BetterTogether::Conversation.create!(
      creator: person,
      title: 'Deletion inventory test',
      participant_ids: [person.id]
    )
    BetterTogether::Message.create!(conversation:, sender: person, content: 'Inventory message')
  end

  it 'captures destroy and retain entries for the linked user and person graph' do
    inventory = described_class.call(person:)
    keys = inventory.fetch(:entries).map { |entry| entry.fetch(:key) }

    expect(keys).to include('user')
    expect(keys).to include('BetterTogether::PersonDataExport#person')
    expect(keys).to include('BetterTogether::Message#sender')
  end

  it 'splits generic creatable creator entries by concrete model' do
    page = create(:better_together_page, creator: person)
    BetterTogether::Authorship.create!(author: person, authorable: page, creator: person)
    create(:better_together_seed, :created_by_person, creator: person)

    inventory = described_class.call(person:)
    entries = inventory.fetch(:entries).index_by { |entry| entry.fetch(:key) }

    expect(entries.fetch('BetterTogether::Creatable#creator:BetterTogether::Authorship')).to include(
      model: 'BetterTogether::Authorship'
    )
    expect(entries.fetch('BetterTogether::Creatable#creator:BetterTogether::Seed')).to include(
      model: 'BetterTogether::Seed'
    )
  end
end
