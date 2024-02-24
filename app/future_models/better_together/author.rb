# frozen_string_literal: true

module BetterTogether
  # Connects to an author (eg: person)
  class Author < ApplicationRecord
    belongs_to :author,
               polymorphic: true,
               required: true

    def to_s
      author.to_s
    end
  end
end
