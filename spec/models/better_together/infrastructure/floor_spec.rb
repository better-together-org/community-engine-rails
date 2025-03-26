# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Infrastructure::Floor, type: :model do
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
          expect(room.persisted?).to be_truthy
        end
      end
    end
  end
end
