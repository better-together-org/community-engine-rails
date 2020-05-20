require 'rails_helper'

RSpec.describe BetterTogether::Authorable, type: :model do
  let(:post) { build(:better_together_authorable) }
  subject { post }

  describe 'has a valid factory' do
    it { is_expected.to be_valid }
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to belong_to(:authorable).required(true) }
  end

  describe 'ActiveModel validations' do

  end

  describe 'callbacks' do

  end
end
