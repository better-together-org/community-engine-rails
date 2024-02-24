# frozen_string_literal: true

module BetterTogether
  # When included, designates a class as Author
  module AuthorConcern
    extend ActiveSupport::Concern

    included do
      has_many :authorships,
               as: :authorable
    end
  end
end
