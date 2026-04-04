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

    it 'exports richer CSL metadata for governance and cooperative evidence records' do
      citation = build(:better_together_citation,
                       source_kind: 'oral_history',
                       source_author: 'Leah Morgan; River Collective',
                       title: 'Oral History Session 4',
                       metadata: {
                         'container_title' => 'Universe 13 Oral History Archive',
                         'medium' => 'Audio interview',
                         'archive' => 'BTS Community Archive',
                         'archive_location' => 'box-4/folder-2',
                         'jurisdiction' => 'NL',
                         'keywords' => %w[governance testimony],
                         'editors' => 'Ada Lovelace'
                       })

      exported = citation.to_csl_json

      expect(exported[:type]).to eq('interview')
      expect(exported[:author]).to include({ family: 'Morgan', given: 'Leah' })
      expect(exported[:author]).to include({ family: 'Collective', given: 'River' })
      expect(exported[:editor]).to eq([{ family: 'Lovelace', given: 'Ada' }])
      expect(exported[:"container-title"]).to eq('Universe 13 Oral History Archive')
      expect(exported[:medium]).to eq('Audio interview')
      expect(exported[:archive]).to eq('BTS Community Archive')
      expect(exported[:archive_location]).to eq('box-4/folder-2')
      expect(exported[:jurisdiction]).to eq('NL')
      expect(exported[:keyword]).to eq(%w[governance testimony])
    end

    it 'exports repository and pull request metadata in CSL-compatible fields' do
      repository = build(:better_together_citation,
                         source_kind: 'repository',
                         title: 'community-engine-rails',
                         metadata: {
                           'repository_name' => 'better-together-org/community-engine-rails',
                           'version' => '0.11.0',
                           'repository_path' => 'pull/1494'
                         })

      pull_request = build(:better_together_citation,
                           source_kind: 'pull_request',
                           title: 'Governed publishing and evidence chain',
                           metadata: {
                             'repository_name' => 'better-together-org/community-engine-rails',
                             'pull_request_number' => 1494
                           })

      expect(repository.to_csl_json[:type]).to eq('software')
      expect(repository.to_csl_json[:"container-title"]).to eq('better-together-org/community-engine-rails')
      expect(repository.to_csl_json[:version]).to eq('0.11.0')
      expect(repository.to_csl_json[:archive_location]).to eq('pull/1494')

      expect(pull_request.to_csl_json[:type]).to eq('post-weblog')
      expect(pull_request.to_csl_json[:"container-title"]).to eq('better-together-org/community-engine-rails')
      expect(pull_request.to_csl_json[:number]).to eq(1494)
      expect(pull_request.to_csl_json[:genre]).to eq('Pull request')
    end
  end
end
