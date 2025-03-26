# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    class Structure < ApplicationRecord
      self.abstract_class = true
    end
  end
end
