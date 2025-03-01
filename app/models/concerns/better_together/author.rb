# frozen_string_literal: true

module BetterTogether
  # When included, designates a class as Author
  module Author
    extend ActiveSupport::Concern

    included do
      has_many :authorships,
               as: :author
      has_many :authorables,
               through: :authorships
    end
  end
end
