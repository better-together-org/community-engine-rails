# frozen_string_literal: true

module BetterTogether
  # Builds importable citation candidates from linked GitHub identities.
  class GithubCitationImportCatalog # rubocop:todo Metrics/ClassLength
    REPOSITORY_LIMIT = 4
    PULL_REQUEST_LIMIT = 2
    ISSUE_LIMIT = 2
    COMMIT_LIMIT = 2

    def initialize(person:)
      @person = person
    end

    def groups
      return [] unless person.respond_to?(:github_integrations)

      person.github_integrations.filter_map do |integration|
        sources = sources_for(integration)
        next if sources.blank?

        {
          label: github_group_label(integration),
          origin: 'github',
          record_type: 'GitHub',
          contribution_role: 'code_contributor',
          contribution_type: 'code',
          citations: sources
        }
      end
    end

    private

    attr_reader :person

    def sources_for(integration) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      preview_sources = preview_sources_for(integration)
      return preview_sources if preview_sources.present?

      github = integration.github_client
      repositories = Array(github.repositories(sort: 'updated', per_page: REPOSITORY_LIMIT))

      repositories.flat_map do |repository|
        full_name = repository.respond_to?(:full_name) ? repository.full_name : nil
        next [] if full_name.blank?

        build_repository_source(repository) +
          build_pull_request_sources(github, repository) +
          build_issue_sources(github, repository) +
          build_commit_sources(github, repository)
      end.compact
    rescue StandardError => e
      Rails.logger.warn("GitHub citation import catalog failed for integration #{integration.id}: #{e.class}: #{e.message}")
      []
    end

    def preview_sources_for(integration)
      Array(integration.auth&.dig('citation_import_preview')).filter_map do |entry|
        preview_source_from(entry)
      end
    end

    def preview_source_from(entry) # rubocop:todo Metrics/AbcSize
      source = entry.deep_symbolize_keys
      source[:metadata] = source[:metadata].is_a?(Hash) ? source[:metadata] : {}
      source[:reference_key] ||= default_reference_key_for(source[:title], source[:source_kind])
      source[:publisher] ||= 'GitHub'
      source[:source_author] ||= source.dig(:metadata, :github_handle)
      source[:accessed_on] ||= Date.current.iso8601
      source.compact
    end

    def build_repository_source(repository) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      {
        reference_key: default_reference_key_for(repository.full_name, 'repository'),
        source_kind: 'repository',
        title: repository.full_name,
        source_author: repository.owner&.login,
        publisher: 'GitHub',
        source_url: repository.html_url,
        excerpt: repository.description,
        accessed_on: Date.current.iso8601,
        metadata: {
          repository_name: repository.full_name,
          repository_path: repository.full_name,
          container_title: repository.full_name,
          version: repository.default_branch,
          keywords: Array(repository.topics),
          github_handle: repository.owner&.login
        }.compact
      }.compact
    end

    def build_pull_request_sources(github, repository) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      Array(
        github.pull_requests(
          repository.full_name,
          state: 'all',
          sort: 'updated',
          direction: 'desc',
          per_page: PULL_REQUEST_LIMIT
        )
      ).map do |pull_request|
        {
          reference_key: default_reference_key_for("#{repository.name}_pr_#{pull_request.number}", 'pull_request'),
          source_kind: 'pull_request',
          title: pull_request.title,
          source_author: pull_request.user&.login,
          publisher: 'GitHub',
          source_url: pull_request.html_url,
          locator: "PR ##{pull_request.number}",
          excerpt: pull_request.body.to_s.truncate(240),
          published_on: safe_date(pull_request.created_at),
          accessed_on: Date.current.iso8601,
          metadata: {
            repository_name: repository.full_name,
            repository_path: repository.full_name,
            pull_request_number: pull_request.number,
            issue_number: pull_request.number,
            container_title: repository.full_name,
            github_handle: pull_request.user&.login
          }.compact
        }.compact
      end
    end

    def build_issue_sources(github, repository) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      issues = Array(
        github.issues_for_repository(
          repository.full_name,
          state: 'all',
          sort: 'updated',
          direction: 'desc',
          per_page: ISSUE_LIMIT
        )
      )

      issues.reject { |issue| issue.respond_to?(:pull_request) && issue.pull_request.present? }.map do |issue|
        {
          reference_key: default_reference_key_for("#{repository.name}_issue_#{issue.number}", 'issue'),
          source_kind: 'issue',
          title: issue.title,
          source_author: issue.user&.login,
          publisher: 'GitHub',
          source_url: issue.html_url,
          locator: "Issue ##{issue.number}",
          excerpt: issue.body.to_s.truncate(240),
          published_on: safe_date(issue.created_at),
          accessed_on: Date.current.iso8601,
          metadata: {
            repository_name: repository.full_name,
            repository_path: repository.full_name,
            issue_number: issue.number,
            container_title: repository.full_name,
            github_handle: issue.user&.login
          }.compact
        }.compact
      end
    end

    def build_commit_sources(github, repository) # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      Array(github.commits(repository.full_name, per_page: COMMIT_LIMIT)).map do |commit|
        sha = commit.sha.to_s.first(12)
        commit_author = commit.author&.login || commit.commit&.author&.name
        {
          reference_key: default_reference_key_for("#{repository.name}_commit_#{sha}", 'commit'),
          source_kind: 'commit',
          title: commit.commit&.message.to_s.lines.first.to_s.strip.presence || "Commit #{sha}",
          source_author: commit_author,
          publisher: 'GitHub',
          source_url: commit.html_url,
          locator: "commit #{sha}",
          excerpt: commit.commit&.message.to_s.truncate(240),
          published_on: safe_date(commit.commit&.author&.date),
          accessed_on: Date.current.iso8601,
          metadata: {
            repository_name: repository.full_name,
            repository_path: repository.full_name,
            commit_sha: commit.sha,
            container_title: repository.full_name,
            github_handle: commit.author&.login
          }.compact
        }.compact
      end
    end

    def safe_date(value)
      value.respond_to?(:to_date) ? value.to_date.iso8601 : nil
    end

    def github_group_label(integration)
      handle = integration.handle.presence || integration.name.presence || integration.uid
      "GitHub: @#{handle}"
    end

    def default_reference_key_for(value, prefix)
      base = value.to_s.parameterize(separator: '_').presence || prefix
      "#{prefix}_#{base}".gsub(/\A#{prefix}_#{prefix}_/, "#{prefix}_").first(80)
    end
  end
end
