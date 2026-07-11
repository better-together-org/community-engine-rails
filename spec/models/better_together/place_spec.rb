# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Place do
  subject(:place) { described_class.new(space: space) }

  let(:space) { create(:geography_space) }
  let(:community) { create(:better_together_community) }

  describe 'associations' do
    it 'responds to community (optional)' do
      expect(place).to respond_to(:community)
    end

    it 'responds to space' do
      expect(place).to respond_to(:space)
    end
  end

  describe 'creation' do
    it 'can be persisted with a space and community' do
      p = create(:better_together_place, space: space, community: community)
      expect(p).to be_persisted
      expect(p.space).to eq(space)
      expect(p.community).to eq(community)
    end
  end
end
