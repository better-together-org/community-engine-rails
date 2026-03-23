# GitHub API Integration with Octokit

This document describes how to use the GitHub API integration in the Better Together Community Engine using OAuth tokens from PersonPlatformIntegration.

## Overview

The engine integrates with GitHub's API through Octokit, using OAuth access tokens obtained during user authentication. This allows you to make authenticated API calls on behalf of users who have connected their GitHub accounts.

## Architecture

```
User → OAuth Sign-In → PersonPlatformIntegration (stores token)
                                ↓
                        BetterTogether::Github
                                ↓
                        Octokit::Client → GitHub API
```

### Key Components

1. **PersonPlatformIntegration**: Stores encrypted OAuth tokens
2. **BetterTogether::Github**: Wrapper around Octokit::Client
3. **Octokit::Client**: Official GitHub API client

## Basic Usage

### Getting a GitHub Client

```ruby
# In a controller or service
def github_integration
  @github_integration ||= current_user.person_platform_integrations.github.first
end

def github_client
  @github_client ||= github_integration.github_client
end
```

### Fetching User Information

```ruby
# Get the authenticated user's GitHub profile
user_info = github_client.user
# => { login: "username", name: "Full Name", bio: "...", ... }

puts user_info[:login]  # GitHub username
puts user_info[:name]   # Display name
puts user_info[:email]  # Public email
```

### Working with Repositories

```ruby
# List all repositories for the authenticated user
repos = github_client.repositories
# => [{ name: "repo1", full_name: "user/repo1", ... }, ...]

# List only public repositories
public_repos = github_client.repositories(type: 'public')

# Get a specific repository
repo = github_client.repository('username/repo-name')
# => { name: "repo-name", description: "...", stars: 42, ... }

# List starred repositories
starred = github_client.starred_repositories
```

### Working with Organizations

```ruby
# List organizations the user belongs to
orgs = github_client.organizations
# => [{ login: "org-name", id: 123, ... }, ...]
```

### Working with Issues

```ruby
# List all issues for the authenticated user
issues = github_client.issues
# => [{ number: 1, title: "Bug report", state: "open", ... }, ...]

# Filter issues by state
open_issues = github_client.issues(state: 'open')
closed_issues = github_client.issues(state: 'closed')

# Filter by labels
bug_issues = github_client.issues(labels: 'bug')
```

### Working with Pull Requests

```ruby
# List pull requests for a repository
prs = github_client.pull_requests('username/repo-name')
# => [{ number: 10, title: "Feature: ...", state: "open", ... }, ...]

# Filter by state
open_prs = github_client.pull_requests('username/repo-name', state: 'open')
```

### Checking Rate Limits

```ruby
# Get current rate limit status
rate_limit = github_client.rate_limit
# => { resources: { core: { limit: 5000, remaining: 4999, reset: ... } } }

remaining = rate_limit[:resources][:core][:remaining]
puts "API calls remaining: #{remaining}"
```

## Advanced Usage

### Direct Octokit Access

For operations not wrapped by the `BetterTogether::Github` class, access the underlying Octokit client:

```ruby
octokit = github_client.client

# Create an issue
octokit.create_issue('username/repo', 'Issue title', 'Issue body')

# Add a comment
octokit.add_comment('username/repo', issue_number, 'Comment text')

# Get repository contributors
contributors = octokit.contributors('username/repo')
```

See [Octokit documentation](https://octokit.github.io/octokit.rb/) for all available methods.

## Token Management

### Automatic Token Refresh

The integration automatically handles token refresh for expired tokens:

```ruby
# The PersonPlatformIntegration#token method checks expiration
# and calls renew_token! if needed
github_client = integration.github_client  # Uses fresh token automatically
```

### Manual Token Refresh

```ruby
# Manually refresh a token
integration.renew_token! if integration.expired?
```

## Error Handling

### Common Errors

```ruby
begin
  repos = github_client.repositories
rescue Octokit::Unauthorized => e
  # Token is invalid or revoked
  flash[:error] = "GitHub authentication failed. Please reconnect your account."
  redirect_to settings_integrations_path
rescue Octokit::TooManyRequests => e
  # Rate limit exceeded
  flash[:error] = "GitHub API rate limit exceeded. Please try again later."
rescue Octokit::NotFound => e
  # Repository or resource not found
  flash[:error] = "GitHub resource not found."
end
```

### Rate Limiting Best Practices

1. **Check rate limits before bulk operations**:
   ```ruby
   rate_limit = github_client.rate_limit
   if rate_limit[:resources][:core][:remaining] < 100
     # Defer operation or show warning
   end
   ```

2. **Cache API responses** when possible:
   ```ruby
   def cached_repositories
     Rails.cache.fetch("github_repos_#{current_user.id}", expires_in: 1.hour) do
       github_client.repositories
     end
   end
   ```

3. **Use conditional requests** for frequently accessed data (see Octokit docs)

## Example: Display User's Repositories

### Controller

```ruby
# app/controllers/github_repositories_controller.rb
class GitHubRepositoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_github_integration

  def index
    @repositories = github_client.repositories(sort: 'updated')
  rescue Octokit::Error => e
    flash.now[:error] = "Error fetching repositories: #{e.message}"
    @repositories = []
  end

  private

  def github_integration
    @github_integration ||= current_user.person_platform_integrations.github.first
  end

  def github_client
    @github_client ||= github_integration.github_client
  end

  def ensure_github_integration
    return if github_integration.present?

    flash[:notice] = "Please connect your GitHub account first."
    redirect_to settings_integrations_path
  end
end
```

### View

```erb
<%# app/views/github_repositories/index.html.erb %>
<h1>Your GitHub Repositories</h1>

<% if @repositories.any? %>
  <ul>
    <% @repositories.each do |repo| %>
      <li>
        <h3><%= link_to repo[:name], repo[:html_url], target: '_blank' %></h3>
        <p><%= repo[:description] %></p>
        <p>
          ⭐ <%= repo[:stargazers_count] %> stars
          • 🍴 <%= repo[:forks_count] %> forks
          • Updated <%= time_ago_in_words(repo[:updated_at]) %> ago
        </p>
      </li>
    <% end %>
  </ul>
<% else %>
  <p>No repositories found.</p>
<% end %>
```

## Security Considerations

### Token Storage

- OAuth tokens are encrypted at rest using Active Record Encryption
- Tokens are stored in `PersonPlatformIntegration#access_token` (encrypted column)
- Never expose tokens in logs, URLs, or client-side code

### Scope Management

OAuth scopes are configured in the OmniAuth initializer:

```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
           ENV.fetch('GITHUB_CLIENT_ID'),
           ENV.fetch('GITHUB_CLIENT_SECRET'),
           scope: 'user,repo'  # Adjust scopes as needed
end
```

Available scopes:
- `user` - Read user profile
- `repo` - Access repositories
- `read:org` - Read organization membership
- `gist` - Access gists
- See [GitHub OAuth Scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)

### User Permissions

Always verify the current user owns the integration:

```ruby
def github_integration
  current_user.person_platform_integrations.github.first
end

# NOT: PersonPlatformIntegration.find(params[:id])
```

## Testing

### RSpec Examples

```ruby
# spec/features/github_integration_spec.rb
RSpec.describe 'GitHub Integration', type: :feature do
  let(:user) { create(:user, :with_github_integration) }
  let(:github_integration) { user.person_platform_integrations.github.first }

  before do
    sign_in user
    
    # Stub Octokit calls
    allow_any_instance_of(Octokit::Client).to receive(:repositories).and_return([
      { name: 'test-repo', description: 'A test repository' }
    ])
  end

  it 'displays GitHub repositories' do
    visit github_repositories_path
    expect(page).to have_content('test-repo')
    expect(page).to have_content('A test repository')
  end
end
```

### Factory

```ruby
# spec/factories/person_platform_integrations.rb
FactoryBot.define do
  factory :person_platform_integration do
    trait :github do
      provider { 'github' }
      access_token { 'gho_test_token_123' }
      # ... other attributes
    end
  end
end
```

## Troubleshooting

### "This integration is not for GitHub" Error

Ensure you're getting a GitHub integration:

```ruby
# Correct
integration = current_user.person_platform_integrations.github.first

# Check if present
if integration.nil?
  # User hasn't connected GitHub
  redirect_to settings_integrations_path
  return
end
```

### Token Expiration

If tokens expire frequently, ensure refresh token is being stored:

```ruby
# Check if refresh is supported
integration.supports_refresh?  # Should return true for GitHub

# Manually trigger refresh
integration.renew_token! if integration.expired?
```

### Rate Limiting

GitHub has rate limits (5,000 requests/hour for authenticated users):

- Check limits: `github_client.rate_limit`
- Cache responses when possible
- Implement background jobs for bulk operations

## Resources

- [Octokit.rb Documentation](https://octokit.github.io/octokit.rb/)
- [GitHub REST API Documentation](https://docs.github.com/en/rest)
- [GitHub OAuth Scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)
- [Better Together OAuth Integration](../oauth_integration_assessment.md)

## Support

For issues or questions:
- Check existing tests in `spec/integrations/better_together/github_spec.rb`
- Review OAuth integration documentation
- Contact the development team
