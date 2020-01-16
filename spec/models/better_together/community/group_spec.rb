require 'rails_helper'

module BetterTogether::Community
  RSpec.describe Group, type: :model do
    let(:group) { build(:better_together_community_group) }
    subject { group }

    describe 'has a valid factory' do
      it { is_expected.to be_valid }
    end

    it_behaves_like 'a friendly slugged record'
    it_behaves_like 'an identity'
    it_behaves_like 'has_bt_id'

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:creator) }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:description) }
    end

    describe 'callbacks' do
    end
  end
end
