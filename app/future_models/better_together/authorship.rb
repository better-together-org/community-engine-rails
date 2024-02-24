# frozen_string_literal: true

module BetterTogether
  class Authorship < ApplicationRecord
    belongs_to :author
    belongs_to :authorable
  end
end
