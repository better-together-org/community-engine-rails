# frozen_string_literal: true

module BetterTogether
  # Persists a GitHub-native citation candidate onto a local citeable record.
  class GithubCitationImportService
    def initialize(record:, source:)
      @record = record
      @source = source.deep_symbolize_keys
    end

    def import!
      citation = existing_citation || record.citations.build
      citation.assign_attributes(citation_attributes)
      citation.metadata = merged_metadata(citation)
      citation.save!
      citation
    end

    private

    attr_reader :record, :source

    def existing_citation
      return @existing_citation if defined?(@existing_citation)

      @existing_citation = record.citations.find_by(reference_key: reference_key) ||
                           record.citations.find_by(source_url: source[:source_url], title: source[:title])
    end

    def citation_attributes
      {
        reference_key: reference_key,
        source_kind: source[:source_kind],
        title: source[:title],
        source_author: source[:source_author],
        publisher: source[:publisher].presence || 'GitHub',
        source_url: source[:source_url],
        locator: source[:locator],
        excerpt: source[:excerpt],
        published_on: parse_date(source[:published_on]),
        accessed_on: parse_date(source[:accessed_on]) || Date.current
      }.compact
    end

    def merged_metadata(citation)
      existing = citation.metadata.is_a?(Hash) ? citation.metadata.deep_dup : {}
      existing.merge(source_metadata)
    end

    def source_metadata
      metadata = source[:metadata].is_a?(Hash) ? source[:metadata].deep_stringify_keys : {}
      metadata.merge(
        'source' => 'github',
        'github_source_kind' => source[:source_kind]
      ).compact
    end

    def reference_key
      source[:reference_key].presence || source[:title].to_s.parameterize(separator: '_')
    end

    def parse_date(value)
      return value if value.is_a?(Date)
      return if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
