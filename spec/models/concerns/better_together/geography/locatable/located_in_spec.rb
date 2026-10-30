# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::Locatable::LocatedIn do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:locations) { BetterTogether::Geography::LocatableLocation }
  let(:settlement) { create(:geography_settlement) }
  let(:elsewhere) { create(:geography_settlement) }
  let(:event) { create(:better_together_event, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour) }
  let(:other_event) { create(:better_together_event, starts_at: 3.days.from_now, ends_at: 3.days.from_now + 1.hour) }

  it 'finds a record located at the place itself', :aggregate_failures do
    event.create_location!(location: settlement)

    expect(BetterTogether::Event.located_in(settlement)).to contain_exactly(event)
    expect(BetterTogether::Event.located_in(elsewhere)).to be_empty
  end

  it 'finds a record at an address that has been resolved into the place', :aggregate_failures do
    address = create(:better_together_address)
    locations.create!(locatable: address, location: settlement)
    event.create_location!(location: address)

    expect(BetterTogether::Event.located_in(settlement)).to contain_exactly(event)
    expect(BetterTogether::Event.located_in(elsewhere)).to be_empty
  end

  it 'leaves out a record with no location and one at an unresolved address', :aggregate_failures do
    other_event.create_location!(location: create(:better_together_address))
    event

    expect(BetterTogether::Event.located_in(settlement)).to be_empty
  end

  it 'lists the ids of records with any explicit location', :aggregate_failures do
    event.create_location!(name: 'Somewhere nice')
    other_event

    ids = BetterTogether::Geography::LocationQueries.explicitly_located_ids(BetterTogether::Event)
    expect(ids.map(&:locatable_id)).to contain_exactly(event.id)
  end

  describe 'a community' do
    let(:community) { create(:better_together_community, privacy: 'public') }
    let(:other_community) { create(:better_together_community, privacy: 'public') }

    it 'is found at the place it is located in, and not elsewhere', :aggregate_failures do
      community.create_location!(location: settlement)
      other_community.create_location!(location: elsewhere)

      expect(BetterTogether::Community.located_in(settlement)).to contain_exactly(community)
      expect(BetterTogether::Community.located_in(elsewhere)).to contain_exactly(other_community)
    end

    it 'is left out when it has no location' do
      community

      expect(BetterTogether::Community.located_in(settlement)).to be_empty
    end
  end

  describe 'a post' do
    let(:community) { create(:better_together_community, privacy: 'public') }
    let(:other_community) { create(:better_together_community, privacy: 'public') }
    let!(:post_here) { create(:better_together_post, community:) }
    let!(:post_there) { create(:better_together_post, community: other_community) }

    before do
      community.create_location!(location: settlement)
      other_community.create_location!(location: elsewhere)
    end

    it 'takes the place of its community', :aggregate_failures do
      expect(BetterTogether::Post.located_in(settlement)).to contain_exactly(post_here)
      expect(BetterTogether::Post.located_in(elsewhere)).to contain_exactly(post_there)
    end

    it 'is left out when its community is not located in the place' do
      expect(BetterTogether::Post.located_in(create(:geography_settlement))).to be_empty
    end
  end

  describe 'inheriting a location' do
    let(:occurrence_class) { BetterTogether::EventOccurrence }
    let(:occurrence) do
      occurrence_class.new(event:, occurrence_date: event.starts_at.to_date).tap { |record| record.save!(validate: false) }
    end

    around do |example|
      occurrence_class.inherit_location_from(:event)
      example.run
    ensure
      occurrence_class.location_inheritance = nil
    end

    it 'takes the parent location only when the record has none of its own', :aggregate_failures do
      event.create_location!(location: settlement)

      expect(occurrence_class.located_in(settlement)).to include(occurrence)

      occurrence.create_location!(location: elsewhere)
      expect(occurrence_class.located_in(settlement)).not_to include(occurrence)
      expect(occurrence_class.located_in(elsewhere)).to include(occurrence)
    end
  end
end
