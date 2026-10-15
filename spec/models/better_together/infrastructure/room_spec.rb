# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Infrastructure::Room do
  subject(:room) { build(:better_together_infrastructure_room) }

  describe 'Factory' do
    it 'has a valid factory' do
      expect(room).to be_valid
    end
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to have_one(:building).through(:floor).class_name('BetterTogether::Infrastructure::Building') }
    it { is_expected.to belong_to(:floor).class_name('BetterTogether::Infrastructure::Floor') }
  end

  describe 'ActiveModel validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'Attributes' do
    it { is_expected.to respond_to(:name) }
    it { is_expected.to respond_to(:description) }
  end

  describe 'Methods' do
    describe '#to_s' do
      it 'returns the name as a string representation' do
        expect(room.to_s).to eq(room.name)
      end
    end

    describe '#level' do
      it 'delegates to the floor' do
        room = create(:better_together_infrastructure_room, floor: create(:better_together_infrastructure_floor, level: 3))

        expect(room.level).to eq(3)
      end
    end

    describe '#building' do
      it 'resolves the room building through the floor' do
        building = create(:better_together_infrastructure_building)
        room = building.reload.floors.first.rooms.first

        expect(room.building).to eq(building)
      end
    end

    describe 'self-geocoding' do
      it 'does not enqueue GeocodingJob for the room itself (Room has no independent space)' do
        allow(BetterTogether::Geography::GeocodingJob).to receive(:perform_later)

        create(:better_together_infrastructure_room)

        expect(BetterTogether::Geography::GeocodingJob).not_to have_received(:perform_later)
          .with(instance_of(described_class))
      end
    end

    describe 'geospatial delegation to building' do
      it 'delegates space/latitude/longitude/geocoded? to the building' do
        room = create(:better_together_infrastructure_room)
        room.building.space.update!(latitude: 47.5615, longitude: -52.7126)

        expect(room.space).to eq(room.building.space)
        expect(room.latitude).to eq(47.5615)
        expect(room.longitude).to eq(-52.7126)
        expect(room.geocoded?).to be(true)
      end

      it 'is not geocoded when the building has no coordinates yet' do
        room = create(:better_together_infrastructure_room)

        expect(room.geocoded?).to be(false)
      end
    end

    describe '#to_leaflet_point' do
      it 'returns nil when the building is not geocoded' do
        room = create(:better_together_infrastructure_room)

        expect(room.to_leaflet_point).to be_nil
      end

      it "uses the building's coordinates but the room's own name as label" do
        room = create(:better_together_infrastructure_room)
        room.building.space.update!(latitude: 47.5615, longitude: -52.7126)

        point = room.to_leaflet_point

        expect(point[:lat]).to eq(47.5615)
        expect(point[:lng]).to eq(-52.7126)
        expect(point[:label]).to eq(room.name)
      end
    end
  end
end
