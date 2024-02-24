# frozen_string_literal: true

module BetterTogether
  class Author < ApplicationRecord
    belongs_to :author,
               polymorphic: true,
               required: true

    def to_s
      author.to_s
    end
  end
end
