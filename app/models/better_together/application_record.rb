module BetterTogether
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    include BetterTogetherId
  end
end
