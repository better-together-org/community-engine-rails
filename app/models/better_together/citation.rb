# frozen_string_literal: true

module BetterTogether
  # Structured citation record for auditable evidence and bibliography export.
  class Citation < ApplicationRecord
    include Positioned
    include BetterTogether::Creatable

    SOURCE_KINDS = %w[
      article
      book
      dataset
      image
      interview
      issue
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

    def apa_citation
      parts = []
      parts << source_author if source_author.present?
      parts << "(#{published_on&.year || 'n.d.'})"
      parts << title
      parts << publisher if publisher.present?
      parts << locator if locator.present?
      parts << source_url if source_url.present?
      parts.compact.join('. ').gsub('..', '.')
    end

    def mla_citation
      parts = []
      parts << source_author if source_author.present?
      parts << %("#{title}")
      parts << publisher if publisher.present?
      parts << published_on.strftime('%-d %b. %Y') if published_on.present?
      parts << locator if locator.present?
      parts << source_url if source_url.present?
      parts.compact.join(', ').sub(', "', ' "')
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

    def to_csl_json
      {
        id: reference_key,
        type: csl_type,
        title: title,
        author: csl_author_list,
        editor: csl_editor_list,
        publisher: publisher.presence,
        "container-title": csl_container_title,
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
        note: rights_notes.presence,
        abstract: excerpt.presence,
        keyword: csl_keywords.presence
      }.compact
    end

    private

    def csl_type
      {
        'article' => 'article-journal',
        'book' => 'book',
        'dataset' => 'dataset',
        'image' => 'graphic',
        'interview' => 'interview',
        'issue' => 'post-weblog',
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
      metadata_value(:genre) ||
        case source_kind
        when 'oral_history'
          'Oral history'
        when 'repository'
          'Software repository'
        when 'pull_request'
          'Pull request'
        when 'policy'
          'Policy document'
        when 'artwork'
          'Artwork'
        when 'story'
          'Story'
        end
    end

    def csl_medium
      metadata_value(:medium) ||
        case source_kind
        when 'video'
          'Video'
        when 'image'
          'Image'
        when 'artwork'
          'Artwork'
        when 'oral_history'
          'Recorded testimony'
        end
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
