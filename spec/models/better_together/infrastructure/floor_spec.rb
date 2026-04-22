# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Infrastructure::Floor do
  subject(:floor) { build(:better_together_infrastructure_floor) }

  describe 'Factory' do
    it 'has a valid factory' do
      expect(floor).to be_valid
    end

    it 'creates a floor with rooms' do
      # byebug
      floor_with_rooms = create(:better_together_infrastructure_floor)
      expect(floor_with_rooms.rooms.count).to eq(1)
    end
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to belong_to(:building).class_name('BetterTogether::Infrastructure::Building') }
    it { is_expected.to have_many(:rooms).class_name('BetterTogether::Infrastructure::Room').dependent(:destroy) }
  end

  describe 'ActiveModel validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:level) }
    it { is_expected.to validate_numericality_of(:level).only_integer }

    it 'validates level uniqueness within a building' do
      building = create(:better_together_infrastructure_building)
      existing_floor = create(:better_together_infrastructure_floor, building:, level: 3)
      duplicate_floor = build(:better_together_infrastructure_floor, building:, level: existing_floor.level)

      expect(duplicate_floor).not_to be_valid
      expect(duplicate_floor.errors[:level]).to be_present
    end
  end

  describe 'Attributes' do
    it { is_expected.to respond_to(:name) }
    it { is_expected.to respond_to(:description) }
    it { is_expected.to respond_to(:level) }
  end

  describe 'Methods' do
    describe '#to_s' do
      it 'returns the name as a string representation' do
        expect(floor.to_s).to eq(floor.name)
      end
    end

    describe '#ensure_room' do
      it 'builds a room if none exist' do
        floor_no_rooms = create(:floor)
        floor_no_rooms.rooms.destroy_all
        room = floor_no_rooms.ensure_room
        expect(floor_no_rooms.rooms.size).to eq(1)
        expect(room).to be_persisted
      end

      it 'does not create another room when one already exists' do
        floor = create(:better_together_infrastructure_floor)
        existing_room = floor.rooms.first

        expect(floor.ensure_room).to be_nil
        expect(floor.rooms.count).to eq(1)
        expect(floor.rooms.first).to eq(existing_room)
      end
    end
  end
end
