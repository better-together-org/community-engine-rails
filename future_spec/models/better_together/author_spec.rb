# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Author do
  subject { author }

  let(:author) { build(:better_together_author) }

  describe 'has a valid factory' do
    it { is_expected.to be_valid }
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to belong_to(:author).required(true) }
  end

  it_behaves_like 'has_id'

  describe '#to_s' do
    it { expect(author.to_s).to equal(author.author.to_s) }
  end
end
