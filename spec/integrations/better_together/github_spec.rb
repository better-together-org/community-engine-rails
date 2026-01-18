# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Github do
  let(:user) { create(:user, :confirmed) }
  let(:person) { user.person }
  let(:github_platform) do
    BetterTogether::Platform.find_or_create_by!(identifier: 'github') do |platform|
      platform.external = true
      platform.host = false
      platform.name = 'GitHub'
      platform.url = 'https://github.com'
      platform.privacy = 'public'
      platform.time_zone = 'UTC'
    end
  end
  let(:github_integration) do
    create(:person_platform_integration,
           :github,
           user:,
           person:,
           platform: github_platform,
           access_token: 'gho_test_token_123')
  end

  describe '#initialize' do
    it 'accepts a GitHub PersonPlatformIntegration' do
      expect { described_class.new(github_integration) }.not_to raise_error
    end

    it 'raises ArgumentError for non-GitHub integration' do
      facebook_platform = BetterTogether::Platform.find_or_create_by!(identifier: 'facebook') do |platform|
        platform.external = true
        platform.host = false
        platform.name = 'Facebook'
        platform.url = 'https://facebook.com'
        platform.privacy = 'public'
        platform.time_zone = 'UTC'
      end
      facebook_integration = create(:person_platform_integration,
                                    :facebook,
                                    user:,
                                    person:,
                                    platform: facebook_platform)

      expect do
        described_class.new(facebook_integration)
      end.to raise_error(ArgumentError, 'Integration must be for GitHub')
    end

    it 'stores the integration' do
      github_client = described_class.new(github_integration)
      expect(github_client.integration).to eq(github_integration)
    end
  end

  describe '#client' do
    let(:github_client) { described_class.new(github_integration) }

    it 'returns an Octokit::Client' do
      expect(github_client.client).to be_a(Octokit::Client)
    end

    it 'uses the integration access token' do
      expect(github_client.client.access_token).to eq('gho_test_token_123')
    end

    it 'memoizes the client' do
      client1 = github_client.client
      client2 = github_client.client
      expect(client1.object_id).to eq(client2.object_id)
    end

    context 'when token is expired' do
      before do
        github_integration.update(expires_at: 1.hour.ago)
        allow(github_integration).to receive_messages(renew_token!: true, token: 'new_token_456')
      end

      it 'refreshes token automatically via integration.token method' do
        client = github_client.client
        expect(client).to be_a(Octokit::Client)
      end
    end
  end

  describe '#user' do
    let(:github_client) { described_class.new(github_integration) }
    let(:mock_user) do
      {
        login: 'testuser',
        id: 123_456,
        name: 'Test User',
        email: 'test@example.com',
        bio: 'Test bio'
      }
    end

    before do
      allow_any_instance_of(Octokit::Client).to receive(:user).and_return(mock_user) # rubocop:todo RSpec/AnyInstance
    end

    it 'returns user information from GitHub API' do
      user_info = github_client.user
      expect(user_info[:login]).to eq('testuser')
      expect(user_info[:name]).to eq('Test User')
    end

    it 'memoizes the user' do
      user1 = github_client.user
      user2 = github_client.user
      expect(user1.object_id).to eq(user2.object_id)
    end
  end

  describe '#repositories' do
    let(:github_client) { described_class.new(github_integration) }
    let(:mock_repos) do
      [
        { name: 'repo1', full_name: 'testuser/repo1', private: false },
        { name: 'repo2', full_name: 'testuser/repo2', private: true }
      ]
    end

    before do
      allow_any_instance_of(Octokit::Client).to receive(:repositories).and_return(mock_repos) # rubocop:todo RSpec/AnyInstance
    end

    it 'returns repositories for the authenticated user' do
      repos = github_client.repositories
      expect(repos.length).to eq(2)
      expect(repos.first[:name]).to eq('repo1')
    end

    it 'accepts options to pass to Octokit' do
      allow_any_instance_of(Octokit::Client).to receive(:repositories) # rubocop:todo RSpec/AnyInstance
        .with(nil, { type: 'public' })
        .and_return([mock_repos.first])

      repos = github_client.repositories(type: 'public')
      expect(repos).to eq([mock_repos.first])
    end
  end

  describe '#starred_repositories' do
    let(:github_client) { described_class.new(github_integration) }
    let(:mock_starred) do
      [
        { name: 'awesome-repo', full_name: 'someone/awesome-repo' }
      ]
    end

    before do
      allow_any_instance_of(Octokit::Client).to receive(:starred).and_return(mock_starred) # rubocop:todo RSpec/AnyInstance
    end

    it 'returns starred repositories' do
      starred = github_client.starred_repositories
      expect(starred.length).to eq(1)
      expect(starred.first[:name]).to eq('awesome-repo')
    end
  end

  describe '#organizations' do
    let(:github_client) { described_class.new(github_integration) }
    let(:mock_orgs) do
      [
        { login: 'test-org', id: 789 }
      ]
    end

    before do
      allow_any_instance_of(Octokit::Client).to receive(:organizations).and_return(mock_orgs) # rubocop:todo RSpec/AnyInstance
    end

    it 'returns organizations for the authenticated user' do
      orgs = github_client.organizations
      expect(orgs.length).to eq(1)
      expect(orgs.first[:login]).to eq('test-org')
    end
  end

  describe '#repository' do
    let(:github_client) { described_class.new(github_integration) }
    let(:mock_repo) do
      { name: 'test-repo', full_name: 'testuser/test-repo', description: 'A test repository' }
    end

    before do
      allow_any_instance_of(Octokit::Client).to receive(:repository).and_return(mock_repo) # rubocop:todo RSpec/AnyInstance
    end

    it 'returns a specific repository' do
      repo = github_client.repository('testuser/test-repo')
      expect(repo[:name]).to eq('test-repo')
      expect(repo[:description]).to eq('A test repository')
    end
  end

  describe '#issues' do
    let(:github_client) { described_class.new(github_integration) }
    let(:mock_issues) do
      [
        { number: 1, title: 'First issue', state: 'open' },
        { number: 2, title: 'Second issue', state: 'closed' }
      ]
    end

    before do
      allow_any_instance_of(Octokit::Client).to receive(:issues).and_return(mock_issues) # rubocop:todo RSpec/AnyInstance
    end

    it 'returns issues for the authenticated user' do
      issues = github_client.issues
      expect(issues.length).to eq(2)
      expect(issues.first[:title]).to eq('First issue')
    end

    it 'accepts options to filter issues' do
      allow_any_instance_of(Octokit::Client).to receive(:issues) # rubocop:todo RSpec/AnyInstance
        .with({ state: 'open' })
        .and_return([mock_issues.first])

      issues = github_client.issues(state: 'open')
      expect(issues).to eq([mock_issues.first])
    end
  end

  describe '#pull_requests' do
    let(:github_client) { described_class.new(github_integration) }
    let(:mock_prs) do
      [
        { number: 10, title: 'First PR', state: 'open' }
      ]
    end

    before do
      allow_any_instance_of(Octokit::Client).to receive(:pull_requests).and_return(mock_prs) # rubocop:todo RSpec/AnyInstance
    end

    it 'returns pull requests for a repository' do
      prs = github_client.pull_requests('testuser/test-repo')
      expect(prs.length).to eq(1)
      expect(prs.first[:title]).to eq('First PR')
    end

    it 'accepts options to filter pull requests' do
      allow_any_instance_of(Octokit::Client).to receive(:pull_requests) # rubocop:todo RSpec/AnyInstance
        .with('testuser/test-repo', { state: 'closed' })
        .and_return([])

      prs = github_client.pull_requests('testuser/test-repo', state: 'closed')
      expect(prs).to eq([])
    end
  end

  describe '#rate_limit' do
    let(:github_client) { described_class.new(github_integration) }
    let(:mock_rate_limit) do
      {
        resources: {
          core: { limit: 5000, remaining: 4999, reset: 1_609_459_200 }
        }
      }
    end

    before do
      allow_any_instance_of(Octokit::Client).to receive(:rate_limit).and_return(mock_rate_limit) # rubocop:todo RSpec/AnyInstance
    end

    it 'returns rate limit information' do
      rate_limit = github_client.rate_limit
      expect(rate_limit[:resources][:core][:limit]).to eq(5000)
      expect(rate_limit[:resources][:core][:remaining]).to eq(4999)
    end
  end

  describe 'error handling' do
    let(:github_client) { described_class.new(github_integration) }

    context 'when API call fails' do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:user) # rubocop:todo RSpec/AnyInstance
          .and_raise(Octokit::Unauthorized.new)
      end

      it 'raises Octokit error' do
        expect { github_client.user }.to raise_error(Octokit::Unauthorized)
      end
    end

    context 'when rate limit is exceeded' do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:repositories) # rubocop:todo RSpec/AnyInstance
          .and_raise(Octokit::TooManyRequests.new)
      end

      it 'raises Octokit rate limit error' do
        expect do
          github_client.repositories
        end.to raise_error(Octokit::TooManyRequests)
      end
    end
  end
end
