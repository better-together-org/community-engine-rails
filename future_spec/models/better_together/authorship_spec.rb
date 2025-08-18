# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Authorship do
  subject { post }

  let(:post) { build(:better_together_authorship) }

  describe 'has a valid factory' do
    it { is_expected.to be_valid }
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to belong_to(:author) }
    it { is_expected.to belong_to(:authorable) }
  end

  describe '#sort_order' do
    it { is_expected.to respond_to(:sort_order) }
  end

  it_behaves_like 'has_id'
end
