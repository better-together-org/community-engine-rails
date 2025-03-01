# frozen_string_literal: true

module BetterTogether
  # When included, designates a class as Authorable
  module Authorable
    extend ActiveSupport::Concern

    included do
      has_many :authorships,
               as: :authorable
      has_many :authors,
               through: :authorships
    end
  end
end
