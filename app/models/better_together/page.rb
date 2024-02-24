# frozen_string_literal: true

module BetterTogether
  class Page < ApplicationRecord
    include FriendlySlug
    include Protected

    PRIVACY_LEVELS = {
      secret: 'secret',
      closed: 'closed',
      public: 'public'
    }.freeze

    enum privacy: PRIVACY_LEVELS,
         _prefix: :privacy

    slugged :title, min_length: 1

    has_rich_text :content

    # Validations
    validates :title, presence: true
    validates :privacy, presence: true, inclusion: { in: %w[public closed secret] }
    validates :language, presence: true

    # Scopes
    scope :published, -> { where(published: true) }
    scope :by_publication_date, -> { order(published_at: :desc) }
    scope :privacy_public, -> { where(privacy: 'public') }

    def published?
      published
    end

    def to_s
      title
    end

    def url
      "#{BetterTogether.base_url}/#{slug}"
    end
  end
end
