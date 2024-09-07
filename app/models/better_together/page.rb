# frozen_string_literal: true

module BetterTogether
  # An informational document used to display custom content to the user
  class Page < ApplicationRecord
    include Identifier
    include Protected
    include Privacy

    PAGE_LAYOUTS = [
      'layouts/better_together/page',
      'layouts/better_together/full_width_page'
    ].freeze

    has_many :page_blocks, dependent: :destroy, class_name: 'BetterTogether::Content::PageBlock'
    has_many :blocks, through: :page_blocks

    accepts_nested_attributes_for :page_blocks, allow_destroy: true

    translates :title, type: :string
    translates :content, backend: :action_text

    slugged :title, min_length: 1

    # Validations
    validates :title, presence: true
    validates :layout, inclusion: { in: PAGE_LAYOUTS }, allow_blank: true

    # Scopes
    scope :published, -> { where.not(published_at: nil) }
    scope :by_publication_date, -> { order(published_at: :desc) }

    def published?
      published_at.present? && published_at < Time.zone.now
    end

    def to_s
      title
    end

    def url
      "#{::BetterTogether.base_url_with_locale}/#{slug}"
    end
  end
end
