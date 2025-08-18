# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Infrastructure::Building, type: :model do
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
        expect(subject).to have_many(:rooms).through(:floors)
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
        it 'creates a floor if none exist' do
          building_no_floors = create(:building)
          building_no_floors.reload
          building_no_floors.floors.destroy_all
          # byebug
          floor = building_no_floors.ensure_floor
          expect(building_no_floors.floors.count).to eq(1)
          expect(floor.persisted?).to be_truthy
        end
      end
    end
  end
end
