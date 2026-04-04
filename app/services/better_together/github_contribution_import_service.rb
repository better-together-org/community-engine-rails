# frozen_string_literal: true

module BetterTogether
  # Persists a GitHub activity mapping into a governed contribution record.
  class GithubContributionImportService
    SOURCE_ROLE_MAPPING = {
      'repository' => BetterTogether::Authorship::AUTHOR_ROLE,
      'pull_request' => BetterTogether::Authorship::AUTHOR_ROLE,
      'commit' => BetterTogether::Authorship::AUTHOR_ROLE,
      'issue' => BetterTogether::Authorship::IDEA_SOURCE_ROLE
    }.freeze

    SOURCE_CONTRIBUTION_TYPE_MAPPING = {
      'repository' => BetterTogether::Authorship::CODE_CONTRIBUTION,
      'pull_request' => BetterTogether::Authorship::CODE_CONTRIBUTION,
      'commit' => BetterTogether::Authorship::CODE_CONTRIBUTION,
      'issue' => BetterTogether::Authorship::DOCUMENTATION_CONTRIBUTION
    }.freeze

    def initialize(record:, contributor:, source:)
      @record = record
      @contributor = contributor
      @source = source.deep_symbolize_keys
    end

    def import!
      contribution = record.contributions.find_or_initialize_by(
        author: contributor,
        role: mapped_role,
        contribution_type: mapped_contribution_type
      )

      contribution.details = merged_details(contribution)
      contribution.save!
      contribution
    end

    private

    attr_reader :record, :contributor, :source

    def mapped_role
      SOURCE_ROLE_MAPPING.fetch(source[:source_kind].to_s, BetterTogether::Authorship::AUTHOR_ROLE)
    end

    def mapped_contribution_type
      SOURCE_CONTRIBUTION_TYPE_MAPPING.fetch(source[:source_kind].to_s, BetterTogether::Authorship::DOCUMENTATION_CONTRIBUTION)
    end

    def merged_details(contribution)
      details = contribution.details.is_a?(Hash) ? contribution.details.deep_dup : {}
      github_sources = Array(details['github_sources']).map(&:deep_stringify_keys)
      source_entry = contribution_source_entry

      unless github_sources.any? do |entry|
        entry['source_kind'] == source_entry['source_kind'] &&
          entry['source_url'] == source_entry['source_url'] &&
          entry['locator'] == source_entry['locator']
      end
        github_sources << source_entry
      end

      details.merge(
        'source' => 'github',
        'github_sources' => github_sources,
        'latest_github_source_kind' => source[:source_kind],
        'repository_name' => source.dig(:metadata, :repository_name),
        'github_handle' => source.dig(:metadata, :github_handle)
      ).compact
    end

    def contribution_source_entry
      {
        'reference_key' => source[:reference_key],
        'source_kind' => source[:source_kind],
        'title' => source[:title],
        'source_url' => source[:source_url],
        'locator' => source[:locator],
        'repository_name' => source.dig(:metadata, :repository_name),
        'pull_request_number' => source.dig(:metadata, :pull_request_number),
        'issue_number' => source.dig(:metadata, :issue_number),
        'commit_sha' => source.dig(:metadata, :commit_sha),
        'github_handle' => source.dig(:metadata, :github_handle)
      }.compact
    end
  end
end
