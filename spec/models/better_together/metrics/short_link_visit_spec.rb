# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::ShortLinkVisit do
  let(:short_link) { create(:better_together_short_link) }

  describe 'validations' do
    subject(:visit) do
      described_class.new(short_link: short_link, visited_at: Time.current)
    end

    it 'is valid with required attributes' do
      expect(visit).to be_valid
    end

    it 'requires visited_at' do
      visit.visited_at = nil
      expect(visit).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a short_link' do
      visit = described_class.create!(short_link: short_link, visited_at: Time.current)
      expect(visit.short_link).to eq(short_link)
    end
  end
end
