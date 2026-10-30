# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CategoryIdentifiers do
  let!(:ships) { create(:category, identifier: 'ships') }
  let!(:sky) { create(:category, identifier: 'sky') }

  %i[better_together_page better_together_post].each do |factory|
    describe "on #{factory}" do
      let(:record) { build(factory) }

      it 'files the record under categories given by identifier', :aggregate_failures do
        record.category_identifiers = %w[ships sky]
        record.save!

        expect(record.reload.categories).to contain_exactly(ships, sky)
        expect(record.category_identifiers).to contain_exactly('ships', 'sky')
      end

      it 'rejects an unknown identifier instead of dropping it', :aggregate_failures do
        record.category_identifiers = %w[ships nope]

        expect(record).not_to be_valid
        expect(record.errors[:base]).to include('unknown categories: nope')
      end

      it 'ignores blanks and duplicates' do
        record.category_identifiers = ['ships', '', 'ships']
        record.save!

        expect(record.reload.categories).to contain_exactly(ships)
      end
    end
  end
end
