module BetterTogether
  class Post < ApplicationRecord
    # self.table_name = "better_together_posts"

    include ::BetterTogether::FriendlySlug
    slugged :title

    translates :title
    translates :content, type: :text

    validates :title,
              presence: true

    validates :content,
              presence: true
  end
end
