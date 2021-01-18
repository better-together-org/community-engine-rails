require 'rails_helper'

module BetterTogether
  RSpec.describe User, type: :model do
    let(:user) { build(:user) }
    subject { user }

    describe 'has a valid factory' do
      it { is_expected.to be_valid }
    end

    describe 'ActiveRecord associations' do
    end

    describe 'ActiveModel validations' do
    end

    describe 'callbacks' do
    end
  end
end
