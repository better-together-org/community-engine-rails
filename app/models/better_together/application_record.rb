# frozen_string_literal: true

module BetterTogether
  # Base model for the engine
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    include BetterTogetherId

    def self.extra_permitted_attributes
      []
    end
  end
end
