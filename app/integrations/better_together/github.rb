# frozen_string_literal: true

require 'octokit'

module BetterTogether
  # GitHub API client using OAuth user tokens from PersonPlatformIntegration.
  # Provides authenticated Octokit client for making API calls on behalf of users.
  #
  # @example
  #   integration = current_user.person_platform_integrations.github.first
  #   github = BetterTogether::Github.new(integration)
  #   repos = github.repositories
  #   user_info = github.user
  class Github
    attr_reader :integration

    def initialize(person_platform_integration)
      @integration = person_platform_integration
      raise ArgumentError, 'Integration must be for GitHub' unless github_integration?
    end

    # Returns an authenticated Octokit client for this user
    # Token is automatically refreshed if expired
    # @return [Octokit::Client]
    def client
      @client ||= Octokit::Client.new(access_token: integration.token)
    end

    # Get the authenticated user's GitHub profile
    # @return [Sawyer::Resource] GitHub user object
    def user
      @user ||= client.user
    end

    # List repositories for the authenticated user
    # @param options [Hash] Options to pass to Octokit
    # @return [Array<Sawyer::Resource>] Array of repository objects
    def repositories(options = {})
      client.repositories(nil, options)
    end

    # List repositories starred by the authenticated user
    # @return [Array<Sawyer::Resource>] Array of repository objects
    def starred_repositories
      client.starred
    end

    # List organizations for the authenticated user
    # @return [Array<Sawyer::Resource>] Array of organization objects
    def organizations
      client.organizations
    end

    # Get a specific repository
    # @param repo [String] Repository in "owner/name" format
    # @return [Sawyer::Resource] Repository object
    def repository(repo)
      client.repository(repo)
    end

    # List issues for the authenticated user
    # @param options [Hash] Options to pass to Octokit
    # @return [Array<Sawyer::Resource>] Array of issue objects
    def issues(options = {})
      client.issues(options)
    end

    # List pull requests for a repository
    # @param repo [String] Repository in "owner/name" format
    # @param options [Hash] Options to pass to Octokit
    # @return [Array<Sawyer::Resource>] Array of pull request objects
    def pull_requests(repo, options = {})
      client.pull_requests(repo, options)
    end

    # Check the current rate limit status
    # @return [Sawyer::Resource] Rate limit information
    def rate_limit
      client.rate_limit
    end

    private

    def github_integration?
      integration.provider == 'github'
    end
  end
end
