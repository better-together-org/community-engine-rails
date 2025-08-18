# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Authorable do
  subject { authorable }

  let(:authorable) { build(:better_together_authorable) }

  describe 'has a valid factory' do
    it { is_expected.to be_valid }
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to belong_to(:authorable).required(true) }
  end

  it_behaves_like 'has_id'

  describe '#to_s' do
    it { expect(authorable.to_s).to equal(authorable.authorable.to_s) }
  end
end
