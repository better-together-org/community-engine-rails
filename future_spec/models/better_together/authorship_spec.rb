# frozen_string_literal: true

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

  describe 'ActiveModel validations' do # rubocop:todo Lint/EmptyBlock
  end

  describe 'callbacks' do # rubocop:todo Lint/EmptyBlock
  end

  describe '#sort_order' do
    it { is_expected.to respond_to(:sort_order) }
  end

  it_behaves_like 'has_id'
end
