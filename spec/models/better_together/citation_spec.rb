# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Citation, type: :model do
  describe 'normalization and formatting' do
    it 'normalizes the reference key from the title when missing' do
      citation = build(:better_together_citation, reference_key: nil, title: 'Oral History Session 4')

      citation.validate

      expect(citation.reference_key).to eq('oral_history_session_4')
    end

    it 'builds APA and MLA export strings from normalized metadata' do
      citation = build(:better_together_citation,
                       source_author: 'Jane Smith',
                       title: 'Shared Reality Notes',
                       publisher: 'Universe 13 Press',
                       published_on: Date.new(2025, 5, 1),
                       locator: 'pp. 12-15',
                       source_url: 'https://example.org/shared-reality')

      expect(citation.apa_citation).to include('Jane Smith')
      expect(citation.apa_citation).to include('(2025)')
      expect(citation.apa_citation).to include('Shared Reality Notes')
      expect(citation.apa_citation).to include('https://example.org/shared-reality')

      expect(citation.mla_citation).to include('Jane Smith')
      expect(citation.mla_citation).to include('"Shared Reality Notes"')
      expect(citation.mla_citation).to include('Universe 13 Press')
    end
  end
end
