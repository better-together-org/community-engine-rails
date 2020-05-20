module BetterTogether
  class Person < ApplicationRecord
    include AuthorConcern
    include FriendlySlug
    include Identity

    slugged :name

    validates :name,
              presence: true

    def to_s
      name
    end
  end
end
