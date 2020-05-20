module BetterTogether
  class Person < ApplicationRecord
    include FriendlySlug
    include Identity

    slugged :name

    validates :name,
              presence: true
  end
end
