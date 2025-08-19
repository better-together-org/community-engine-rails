# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Infrastructure::Room do
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
    end
  end
end
