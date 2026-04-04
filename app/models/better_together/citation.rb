# frozen_string_literal: true

module BetterTogether
  # Structured citation record for auditable evidence and bibliography export.
  class Citation < ApplicationRecord # rubocop:todo Metrics/ClassLength
    include Positioned
    include BetterTogether::Creatable

    SOURCE_KINDS = %w[
      article
      book
      dataset
      image
      interview
      issue
      commit
      oral_history
      policy
      pull_request
      repository
      story
      survey
      video
      webpage
      artwork
    ].freeze

    CSL_GENRES = {
      'oral_history' => 'Oral history',
      'repository' => 'Software repository',
      'pull_request' => 'Pull request',
      'policy' => 'Policy document',
      'artwork' => 'Artwork',
      'story' => 'Story'
    }.freeze

    CSL_MEDIA = {
      'video' => 'Video',
      'image' => 'Image',
      'artwork' => 'Artwork',
      'oral_history' => 'Recorded testimony'
    }.freeze

    belongs_to :citeable, polymorphic: true

    before_validation :normalize_reference_key

    validates :reference_key, presence: true, format: { with: /\A[a-z0-9_-]+\z/ }
    validates :source_kind, presence: true, inclusion: { in: SOURCE_KINDS }
    validates :title, presence: true
    validates :source_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
    validates :reference_key, uniqueness: { scope: %i[citeable_type citeable_id] }

    scope :ordered, -> { order(:position, :created_at) }

    def anchor_id
      "citation-#{reference_key}"
    end

    def display_reference
      [source_author.presence, title.presence, publisher.presence].compact.join('. ')
    end

    def apa_citation(include_provenance: false) # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity
      parts = []
      parts << source_author if source_author.present?
      parts << "(#{published_on&.year || 'n.d.'})"
      parts << title
      parts << publisher if publisher.present?
      parts << locator if locator.present?
      parts << source_url if source_url.present?
      citation_text = parts.compact.join('. ').gsub('..', '.')
      include_provenance ? [citation_text, provenance_note].compact.join(' ') : citation_text
    end

    def mla_citation(include_provenance: false) # rubocop:todo Metrics/AbcSize
      parts = []
      parts << source_author if source_author.present?
      parts << %("#{title}")
      parts << publisher if publisher.present?
      parts << published_on.strftime('%-d %b. %Y') if published_on.present?
      parts << locator if locator.present?
      parts << source_url if source_url.present?
      citation_text = parts.compact.join(', ').sub(', "', ' "')
      include_provenance ? [citation_text, provenance_note].compact.join(' ') : citation_text
    end

    def accessible_reference
      display_reference.presence || title
    end

    def imported_from_linked_record?
      imported_from_citation_id.present? || imported_from_reference_key.present?
    end

    def imported_from_reference_key
      metadata_value(:imported_from_reference_key)
    end

    def imported_from_citation_id
      metadata_value(:imported_from_citation_id)
    end

    def imported_from_record_label
      metadata_value(:imported_from_record_label)
    end

    def imported_from_record_type
      metadata_value(:imported_from_record_type)
    end

    def import_audit_summary
      return unless imported_from_linked_record?

      [
        imported_from_record_label.presence || imported_from_record_type.presence,
        imported_from_reference_key.presence
      ].compact.join(' | ')
    end

    def provenance_note
      return unless imported_from_linked_record?

      "Imported from linked citation: #{import_audit_summary}"
    end

    def to_csl_json(include_provenance: false) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      {
        id: reference_key,
        type: csl_type,
        title: title,
        author: csl_author_list,
        editor: csl_editor_list,
        publisher: publisher.presence,
        'container-title': csl_container_title,
        genre: csl_genre,
        medium: csl_medium,
        version: csl_version,
        number: csl_number,
        archive: csl_archive,
        archive_location: csl_archive_location,
        language: csl_language,
        jurisdiction: csl_jurisdiction,
        URL: source_url.presence,
        issued: csl_date_hash(published_on),
        accessed: csl_date_hash(accessed_on),
        locator: locator.presence,
        note: csl_note(include_provenance:),
        abstract: excerpt.presence,
        keyword: csl_keywords.presence
      }.compact
    end

    def governance_bundle_payload(include_provenance: false) # rubocop:todo Metrics/MethodLength
      {
        id: id,
        reference_key: reference_key,
        source_kind: source_kind,
        title: title,
        source_author: source_author,
        publisher: publisher,
        source_url: source_url,
        locator: locator,
        excerpt: excerpt,
        imported_from_linked_record: imported_from_linked_record?,
        import_audit_summary: import_audit_summary,
        csl: to_csl_json(include_provenance:),
        platform_metadata: governance_platform_metadata
      }.compact
    end

    private

    def csl_type # rubocop:todo Metrics/MethodLength
      {
        'article' => 'article-journal',
        'book' => 'book',
        'dataset' => 'dataset',
        'image' => 'graphic',
        'interview' => 'interview',
      'issue' => 'post-weblog',
      'commit' => 'post-weblog',
        'oral_history' => 'interview',
        'policy' => 'report',
        'pull_request' => 'post-weblog',
        'repository' => 'software',
        'story' => 'chapter',
        'survey' => 'dataset',
        'video' => 'motion_picture',
        'webpage' => 'webpage',
        'artwork' => 'graphic'
      }.fetch(source_kind, 'document')
    end

    def csl_author_list
      return unless source_author.present?

      parse_name_list(source_author)
    end

    def csl_editor_list
      return unless metadata_value(:editors).present?

      parse_name_list(metadata_value(:editors))
    end

    def csl_date_hash(date)
      return unless date.present?

      { 'date-parts' => [[date.year, date.month, date.day].compact] }
    end

    def csl_container_title
      metadata_value(:container_title) ||
        metadata_value(:repository_name) ||
        metadata_value(:collection_title)
    end

    def csl_genre
      metadata_value(:genre) || CSL_GENRES[source_kind]
    end

    def csl_medium
      metadata_value(:medium) || CSL_MEDIA[source_kind]
    end

    def csl_version
      metadata_value(:version) || metadata_value(:software_version)
    end

    def csl_number
      metadata_value(:number) || metadata_value(:pull_request_number)
    end

    def csl_archive
      metadata_value(:archive) || metadata_value(:collection)
    end

    def csl_archive_location
      metadata_value(:archive_location) || metadata_value(:repository_path)
    end

    def csl_language
      metadata_value(:language)
    end

    def csl_jurisdiction
      metadata_value(:jurisdiction)
    end

    def csl_keywords
      raw_keywords = metadata_value(:keywords)
      return raw_keywords if raw_keywords.is_a?(Array)
      return raw_keywords.split(';').map(&:strip).reject(&:blank?) if raw_keywords.is_a?(String)

      []
    end

    def metadata_value(key)
      metadata[key.to_s].presence || metadata[key.to_sym].presence
    end

    def governance_platform_metadata
      selected = metadata.slice(
        'repository_name',
        'repository_path',
        'pull_request_number',
        'issue_number',
        'commit_sha',
        'github_handle',
        'version',
        'archive_location',
        'container_title'
      )
      selected.presence
    end

    def csl_note(include_provenance: false)
      notes = []
      notes << rights_notes.presence
      notes << provenance_note if include_provenance
      notes.compact.join(' ').presence
    end

    def parse_name_list(value)
      value.to_s.split(';').filter_map do |author_name|
        normalized_name = author_name.strip
        next if normalized_name.blank?

        parts = normalized_name.split
        next({ literal: normalized_name }) if parts.length <= 1

        {
          family: parts.last,
          given: parts[0..-2].join(' ')
        }
      end.presence
    end

    def normalize_reference_key
      candidate = reference_key.presence || title.to_s.parameterize(separator: '_')
      self.reference_key = candidate.to_s.downcase.gsub(/[^a-z0-9_-]/, '_').squeeze('_').presence || 'citation'
    end
  end
end
