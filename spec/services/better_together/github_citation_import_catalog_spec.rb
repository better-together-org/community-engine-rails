# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::GithubCitationImportCatalog, type: :service do
  let(:person) { create(:better_together_person) }

  describe '#groups' do
    context 'when the person does not respond to github_integrations' do
      it 'returns an empty array' do
        expect(described_class.new(person:).groups).to eq([])
      end
    end

    context 'when the person has a github integration with preview sources' do
      let(:preview_sources) do
        [
          {
            'source_kind' => 'pull_request',
            'title' => 'Fix auth bug',
            'source_url' => 'https://github.com/org/repo/pull/1',
            'locator' => 'PR #1',
            'metadata' => { 'repository_name' => 'org/repo', 'github_handle' => 'robsmith' }
          }
        ]
      end

      let(:integration) do
        # rubocop:disable RSpec/VerifiedDoubles
        double('integration',
               auth: { 'citation_import_preview' => preview_sources },
               handle: 'robsmith',
               name: 'Rob Smith',
               uid: '12345')
        # rubocop:enable RSpec/VerifiedDoubles
      end

      before do
        allow(person).to receive(:github_integrations).and_return([integration])
      end

      it 'returns one group for the integration' do
        expect(described_class.new(person:).groups.size).to eq(1)
      end

      it 'the group has the expected keys' do
        group = described_class.new(person:).groups.first
        expect(group).to include(:label, :origin, :record_type, :citations)
      end

      it 'sets origin to github' do
        expect(described_class.new(person:).groups.first[:origin]).to eq('github')
      end

      it 'the group label includes the github handle' do
        expect(described_class.new(person:).groups.first[:label]).to include('robsmith')
      end

      it 'maps preview sources to citation hashes with source_kind' do
        citation = described_class.new(person:).groups.first[:citations].first
        expect(citation[:source_kind]).to eq('pull_request')
      end

      it 'maps preview sources to citation hashes with title' do
        citation = described_class.new(person:).groups.first[:citations].first
        expect(citation[:title]).to eq('Fix auth bug')
      end

      it 'defaults publisher to GitHub' do
        citation = described_class.new(person:).groups.first[:citations].first
        expect(citation[:publisher]).to eq('GitHub')
      end

      it 'generates a reference_key when not provided in preview' do
        citation = described_class.new(person:).groups.first[:citations].first
        expect(citation[:reference_key]).to be_present
      end
    end

    context 'when the integration has no preview sources and the github client raises' do
      let(:integration) do
        # rubocop:disable RSpec/VerifiedDoubles
        double('integration',
               id: 99,
               auth: {},
               handle: 'robsmith',
               name: 'Rob Smith',
               uid: '12345',
               github_client: double('Octokit::Client')) # rubocop:disable RSpec/VerifiedDoubles
        # rubocop:enable RSpec/VerifiedDoubles
      end

      before do
        allow(person).to receive(:github_integrations).and_return([integration])
        allow(integration.github_client).to receive(:repositories).and_raise(StandardError, 'API error')
      end

      it 'swallows the error and returns an empty group list' do
        expect { described_class.new(person:).groups }.not_to raise_error
        expect(described_class.new(person:).groups).to eq([])
      end
    end
  end
end
