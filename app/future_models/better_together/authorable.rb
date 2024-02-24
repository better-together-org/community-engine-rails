# frozen_string_literal: true

module BetterTogether
  # Connects to an authorable resource (eg: post)
  class Authorable < ApplicationRecord
    belongs_to :authorable,
               polymorphic: true,
               required: true

    def to_s
      authorable.to_s
    end
  end
end
