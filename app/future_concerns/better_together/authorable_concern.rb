module BetterTogether
  module AuthorableConcern
    extend ActiveSupport::Concern

    included do
      has_many :authorships,
               as: :authorable
      has_many :authors,
               through: :authorships
    end
  end
end
