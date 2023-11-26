module BetterTogether
  class Page < ApplicationRecord
    include FriendlySlug
    
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
    validates :page_privacy, presence: true, inclusion: { in: %w[public closed secret] }
    validates :language, presence: true

    # Scopes
    scope :published, -> { where(published: true) }
    scope :by_publication_date, -> { order(published_at: :desc) }
    scope :public_pages, -> { where(page_privacy: 'public') }

    def to_s
      title
    end

    def url
      "#{BetterTogether.base_url}/#{slug}"
    end
  end
end
