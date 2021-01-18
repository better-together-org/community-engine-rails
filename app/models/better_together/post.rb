module BetterTogether
  class Post < ApplicationRecord
    PRIVACY_LEVELS = {
      private: 'private',
      public: 'public'
    }.freeze

    include AuthorableConcern
    include FriendlySlug

    slugged :title

    translates :title
    translates :content, type: :text
    translates :content_html, type: :text

    enum post_privacy: PRIVACY_LEVELS,
         _prefix: :post_privacy

    validates :title,
              presence: true

    validates :content,
              presence: true

    def self.draft
      where(arel_table[:published_at].eq(nil))
    end

    def self.published
      where(arel_table[:published_at].lteq(DateTime.current))
    end

    def self.scheduled
      where(arel_table[:published_at].gt(DateTime.current))
    end

    def draft?
      published_at.nil?
    end

    def published?
      published_at <= DateTime.current
    end

    def scheduled?
      published_at >= DateTime.current
    end

    def to_s
      title
    end
  end
end
