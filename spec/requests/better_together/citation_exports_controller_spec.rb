# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::CitationExportsController', :as_user do
  let(:locale) { I18n.default_locale }

  describe 'GET /citations/export/:citeable_key/:id' do
    let(:page) { create(:better_together_page, privacy: 'public', published_at: 1.day.ago) }

    before do
      create(:citation,
             citeable: page,
             reference_key: 'shared-reality',
             source_kind: 'policy',
             title: 'Shared Reality Charter',
             source_author: 'Better Together',
             publisher: 'BTS',
             source_url: 'https://example.org/charter',
             published_on: Date.new(2026, 4, 4))
    end

    it 'exports CSL JSON for a public citeable record' do
      get better_together.citation_export_path(citeable_key: 'page', id: page.slug, locale:, style: 'csl')

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['format']).to eq('csl-json')
      expect(json['citations'].first['title']).to eq('Shared Reality Charter')
      expect(json['citations'].first['type']).to eq('report')
    end

    it 'exports APA lines as plain text' do
      get better_together.citation_export_path(citeable_key: 'page', id: page.slug, locale:, style: 'apa')

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/plain')
      expect(response.body).to include('Shared Reality Charter')
    end

    it 'optionally includes provenance in exported citation output' do
      page.citations.first.update!(
        metadata: {
          'imported_from_reference_key' => 'review_notes',
          'imported_from_record_label' => 'Consensus Reviewer: Reviewer',
          'imported_from_citation_id' => 'source-citation-id'
        }
      )

      get better_together.citation_export_path(citeable_key: 'page', id: page.slug, locale:, style: 'csl',
                                               include_provenance: true)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['include_provenance']).to eq(true)
      expect(json['citations'].first['note']).to include('Imported from linked citation:')

      get better_together.citation_export_path(citeable_key: 'page', id: page.slug, locale:, style: 'apa',
                                               include_provenance: true)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Imported from linked citation:')
    end
  end
end
