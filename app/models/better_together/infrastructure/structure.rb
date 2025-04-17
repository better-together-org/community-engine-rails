# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    # Abstract parent class for all structures
    class Structure < ApplicationRecord
      self.abstract_class = true
    end
  end
end
