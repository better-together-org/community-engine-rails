# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Infrastructure::Building do
  subject(:building) { build(:better_together_infrastructure_building) }

  describe 'Factory' do
    it 'has a valid factory' do
      expect(building).to be_valid
    end

    it 'creates a building with floors' do
      building_with_floors = create(:better_together_infrastructure_building)

      expect(building_with_floors.floors.size).to eq(1)
    end

    it 'builds a building with rooms' do
      building_with_rooms = create(:better_together_infrastructure_building)
      expect(building_with_rooms.rooms.size).to eq(1)
    end
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to have_many(:floors).class_name('BetterTogether::Infrastructure::Floor').dependent(:destroy) }

    it {
      expect(subject).to have_many(:rooms).through(:floors) # rubocop:todo RSpec/NamedSubject
                                          .class_name('BetterTogether::Infrastructure::Room').dependent(:destroy)
    }
  end

  describe 'ActiveModel validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'Attributes' do
    it { is_expected.to respond_to(:name) }
    it { is_expected.to respond_to(:description) }
    it { is_expected.to respond_to(:slug) }
    it { is_expected.to respond_to(:floors_count) }
    it { is_expected.to respond_to(:rooms_count) }
  end

  describe 'Methods' do
    describe '#to_s' do
      it 'returns the name as a string representation' do
        expect(building.to_s).to eq(building.name)
      end
    end

    describe '#ensure_floor' do
      # rubocop:todo RSpec/MultipleExpectations
      it 'creates a floor if none exist' do # rubocop:todo RSpec/MultipleExpectations
        # rubocop:enable RSpec/MultipleExpectations
        building_no_floors = create(:building)
        building_no_floors.reload
        building_no_floors.floors.destroy_all
        # byebug
        floor = building_no_floors.ensure_floor
        expect(building_no_floors.floors.count).to eq(1)
        expect(floor).to be_persisted
      end

      it 'does not create another floor when one already exists', :aggregate_failures do
        building = create(:better_together_infrastructure_building)
        existing_floor = building.floors.first

        expect(building.ensure_floor).to be_nil
        expect(building.floors.count).to eq(1)
        expect(building.floors.first).to eq(existing_floor)
      end
    end

    describe '#name_is_address?' do
      it 'returns true when the name matches the address geocoding string' do
        address = create(:better_together_address,
                         line1: '62 Broadway',
                         city_name: 'Corner Brook',
                         state_province_name: 'NL',
                         country_name: 'Canada')
        building = create(:better_together_infrastructure_building, address:)
        building.update!(name: address.geocoding_string)

        expect(building.name_is_address?).to be(true)
      end
    end

    describe '#select_option_title' do
      it 'includes the name and slug' do
        building = create(:better_together_infrastructure_building, name: 'Community Hall')

        expect(building.select_option_title).to eq("#{building.name} (#{building.slug})")
      end
    end

    describe '#schedule_address_geocoding' do
      it 'enqueues geocoding when the address can be geocoded' do
        allow(BetterTogether::Geography::GeocodingJob).to receive(:perform_later)
        address = create(:better_together_address,
                         line1: '62 Broadway',
                         city_name: 'Corner Brook',
                         state_province_name: 'NL',
                         country_name: 'Canada')

        create(:better_together_infrastructure_building, address:)

        expect(BetterTogether::Geography::GeocodingJob).to have_received(:perform_later)
          .with(instance_of(described_class))
      end
    end
  end
end
