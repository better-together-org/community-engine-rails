# frozen_string_literal: true

module BetterTogether
  # Represents a blog post
  class Post < ApplicationRecord
    include Authorable
    include BlockFilterable
    include FriendlySlug
    include Categorizable
    include Creatable
    include Identifier
    include Metrics::Viewable
    include Privacy
    include Publishable

    categorizable

    translates :title
    translates :content, backend: :action_text

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
