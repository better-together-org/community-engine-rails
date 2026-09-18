# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::GithubCitationImportService do
  let(:platform) { create(:better_together_platform, :public) }
  let(:record) { create(:better_together_page, platform:) }

  let(:source) do
    {
      source_kind: 'pull_request',
      title: 'Fix login bug',
      source_url: 'https://github.com/org/repo/pull/42',
      locator: 'pr/42',
      source_author: 'robsmith',
      excerpt: 'Fixes the login flow',
      publisher: 'GitHub',
      metadata: { repository_name: 'org/repo', pull_request_number: 42 }
    }
  end

  describe '#import!' do
    it 'creates a citation on the record' do
      expect do
        described_class.new(record:, source:).import!
      end.to change { record.citations.count }.by(1)
    end

    it 'persists the source metadata' do
      citation = described_class.new(record:, source:).import!
      expect(citation.source_url).to eq('https://github.com/org/repo/pull/42')
      expect(citation.title).to eq('Fix login bug')
    end

    it 'defaults publisher to GitHub when not specified' do
      citation = described_class.new(record:, source: source.except(:publisher)).import!
      expect(citation.publisher).to eq('GitHub')
    end

    it 'is idempotent — calling twice does not create a duplicate citation' do
      described_class.new(record:, source:).import!
      expect do
        described_class.new(record:, source:).import!
      end.not_to(change { record.citations.count })
    end
  end
end
