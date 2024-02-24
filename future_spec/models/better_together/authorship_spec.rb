require 'rails_helper'

RSpec.describe BetterTogether::Authorship, type: :model do
  let(:post) { build(:better_together_authorship) }
  subject { post }

  describe 'has a valid factory' do
    it { is_expected.to be_valid }
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to belong_to(:author) }
    it { is_expected.to belong_to(:authorable) }
  end

  describe 'ActiveModel validations' do
  end

  describe 'callbacks' do
  end

  describe '#sort_order' do
    it { is_expected.to respond_to(:sort_order) }
  end

  it_behaves_like 'has_bt_id'
end
