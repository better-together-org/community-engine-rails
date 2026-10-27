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
