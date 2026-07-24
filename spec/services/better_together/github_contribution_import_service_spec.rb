# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::GithubContributionImportService do
  let(:platform) { create(:better_together_platform, :public) }
  let(:contributor) { create(:better_together_person) }
  let(:record) { create(:better_together_post, platform:, privacy: 'public') }

  let(:pull_request_source) do
    {
      source_kind: 'pull_request',
      reference_key: 'pr-42',
      title: 'Fix login bug',
      source_url: 'https://github.com/org/repo/pull/42',
      locator: 'pr/42',
      metadata: {
        repository_name: 'org/repo',
        pull_request_number: 42,
        github_handle: 'robsmith'
      }
    }
  end

  let(:issue_source) do
    {
      source_kind: 'issue',
      reference_key: 'issue-99',
      title: 'Bug report',
      source_url: 'https://github.com/org/repo/issues/99',
      locator: 'issue/99',
      metadata: { repository_name: 'org/repo', issue_number: 99, github_handle: 'robsmith' }
    }
  end

  describe '#import!' do
    it 'creates an Authorship contribution on the record' do
      expect do
        described_class.new(record:, contributor:, source: pull_request_source).import!
      end.to change { record.contributions.count }.by(1)
    end

    it 'assigns the author role for pull_request source_kind' do
      contribution = described_class.new(record:, contributor:, source: pull_request_source).import!
      expect(contribution.role).to eq(BetterTogether::Authorship::AUTHOR_ROLE)
    end

    it 'assigns the idea_source role for issue source_kind' do
      contribution = described_class.new(record:, contributor:, source: issue_source).import!
      expect(contribution.role).to eq(BetterTogether::Authorship::IDEA_SOURCE_ROLE)
    end

    it 'assigns code contribution_type for pull_request source_kind' do
      contribution = described_class.new(record:, contributor:, source: pull_request_source).import!
      expect(contribution.contribution_type).to eq(BetterTogether::Authorship::CODE_CONTRIBUTION)
    end

    it 'stores github source metadata in details' do
      contribution = described_class.new(record:, contributor:, source: pull_request_source).import!
      expect(contribution.details['source']).to eq('github')
      expect(contribution.details['repository_name']).to eq('org/repo')
      expect(contribution.details['github_handle']).to eq('robsmith')
    end

    it 'is idempotent — calling twice does not create a duplicate contribution' do
      described_class.new(record:, contributor:, source: pull_request_source).import!
      expect do
        described_class.new(record:, contributor:, source: pull_request_source).import!
      end.not_to(change { record.contributions.count })
    end

    it 'accumulates github_sources when called with a new source entry' do
      described_class.new(record:, contributor:, source: pull_request_source).import!

      commit_source = pull_request_source.merge(source_kind: 'commit', reference_key: 'sha-abc', locator: 'commit/abc')
      contribution = described_class.new(record:, contributor:, source: commit_source).import!

      expect(contribution.details['github_sources'].size).to eq(2)
    end
  end
end
