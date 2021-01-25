require 'rails_helper'

module BetterTogether
  RSpec.describe User, type: :model do
    let(:user) { build(:user) }
    subject { user }

    describe 'has a valid factory' do
      it { is_expected.to be_valid }
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to have_one(:person_identification) }
      it { is_expected.to have_one(:person) }
      it { is_expected.to accept_nested_attributes_for(:person) }
    end

    describe 'ActiveModel validations' do
    end

    describe 'callbacks' do
    end
  end
end
