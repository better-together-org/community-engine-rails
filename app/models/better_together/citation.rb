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

    def to_csl_json
      {
        id: reference_key,
        type: csl_type,
        title: title,
        author: csl_author_list,
        publisher: publisher.presence,
        URL: source_url.presence,
        issued: csl_date_hash(published_on),
        accessed: csl_date_hash(accessed_on),
        locator: locator.presence,
        note: rights_notes.presence,
        abstract: excerpt.presence
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

      source_author.split(';').map do |author_name|
        parts = author_name.strip.split
        next { literal: author_name.strip } if parts.length <= 1

        {
          family: parts.last,
          given: parts[0..-2].join(' ')
        }
      end
    end

    def csl_date_hash(date)
      return unless date.present?

      { 'date-parts' => [[date.year, date.month, date.day].compact] }
    end

    def normalize_reference_key
      candidate = reference_key.presence || title.to_s.parameterize(separator: '_')
      self.reference_key = candidate.to_s.downcase.gsub(/[^a-z0-9_-]/, '_').squeeze('_').presence || 'citation'
    end
  end
end
