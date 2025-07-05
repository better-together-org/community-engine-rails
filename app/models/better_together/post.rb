# frozen_string_literal: true

module BetterTogether
  # Represents a blog post
  class Post < ApplicationRecord
    include Authorable
    include FriendlySlug
    include Categorizable
    include Identifier
    include Privacy
    include Publishable

    categorizable

    translates :title
    translates :content, type: :text
    # translates :content_html, type: :action_text

    slugged :title

    validates :title,
              presence: true

    validates :content,
              presence: true

    def to_s
      title
    end
  end
end
