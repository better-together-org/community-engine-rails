# frozen_string_literal: true

module BetterTogether
  # Persists a GitHub activity mapping into a governed contribution record.
  class GithubContributionImportService
    SOURCE_ENTRY_KEYS = %i[reference_key source_kind title source_url locator].freeze
    SOURCE_METADATA_KEYS = {
      repository_name: :repository_name,
      pull_request_number: :pull_request_number,
      issue_number: :issue_number,
      commit_sha: :commit_sha,
      github_handle: :github_handle
    }.freeze

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
      details = contribution_details(contribution)
      details.merge(
        'source' => 'github',
        'github_sources' => merged_github_sources(details),
        'latest_github_source_kind' => source[:source_kind],
        'repository_name' => source.dig(:metadata, :repository_name),
        'github_handle' => source.dig(:metadata, :github_handle)
      ).compact
    end

    def contribution_source_entry
      source.slice(*SOURCE_ENTRY_KEYS)
            .deep_stringify_keys
            .merge(source_entry_metadata)
            .compact
    end

    def contribution_details(contribution)
      contribution.details.is_a?(Hash) ? contribution.details.deep_dup : {}
    end

    def merged_github_sources(details)
      github_sources = Array(details['github_sources']).map(&:deep_stringify_keys)
      source_entry = contribution_source_entry
      return github_sources if github_source_exists?(github_sources, source_entry)

      github_sources + [source_entry]
    end

    def github_source_exists?(github_sources, source_entry)
      github_sources.any? { |entry| source_identity(entry) == source_identity(source_entry) }
    end

    def source_identity(entry)
      entry.values_at('source_kind', 'source_url', 'locator')
    end

    def source_entry_metadata
      SOURCE_METADATA_KEYS.each_with_object({}) do |(key, metadata_key), metadata|
        metadata[key.to_s] = source.dig(:metadata, metadata_key)
      end
    end
  end
end
