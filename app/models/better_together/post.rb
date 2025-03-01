# frozen_string_literal: true

module BetterTogether
  # Represents a blog post
  class Post < ApplicationRecord
    PRIVACY_LEVELS = {
      private: 'private',
      public: 'public'
    }.freeze

    include AuthorableConcern
    include FriendlySlug
    include Categorizable
    include Identifier
    include Privacy
    include Publishable
    include Searchable

    slugged :title

    translates :title
    translates :content, type: :text
    # translates :content_html, type: :action_text

    enum post_privacy: PRIVACY_LEVELS,
         _prefix: :post_privacy

    validates :title,
              presence: true

    validates :content,
              presence: true

    settings index: { number_of_shards: 1 } do
      mappings dynamic: 'false' do
        indexes :title, as: 'title'
        indexes :content, as: 'content'
      end
    end

    def to_s
      title
    end
  end
end
