# frozen_string_literal: true

module BetterTogether
  # Connects an author (eg: person) to an authorable (eg: post)
  class Authorship < ApplicationRecord
    belongs_to :author
    belongs_to :authorable
  end
end
