require 'rails_helper'

RSpec.describe BetterTogether::Author, type: :model do
  let(:author) { build(:better_together_author) }
  subject { author }

  describe 'has a valid factory' do
    it { is_expected.to be_valid }
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to belong_to(:author).required(true) }
  end

  describe 'ActiveModel validations' do

  end

  describe 'callbacks' do

  end
  
  it_behaves_like 'has_bt_id'
end
