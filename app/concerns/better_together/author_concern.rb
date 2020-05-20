
module BetterTogether
  module AuthorConcern
    extend ActiveSupport::Concern

    included do
      has_many :authorships,
               as: :authorable
      has_many :authorables,
               through: :authorships
    end

  end
end
