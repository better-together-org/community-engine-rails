# frozen_string_literal: true

module BetterTogether
  # Connects an author (eg: person) to an authorable (eg: post)
  class Authorship < ApplicationRecord
    include Positioned

    belongs_to :author,
               class_name: 'BetterTogether::Person'
    belongs_to :authorable,
               polymorphic: true
  end
end
