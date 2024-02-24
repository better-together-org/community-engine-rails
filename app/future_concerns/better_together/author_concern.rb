# frozen_string_literal: true

module BetterTogether
  module AuthorConcern
    extend ActiveSupport::Concern

    included do
      has_many :authorships,
               as: :authorable
    end
  end
end
