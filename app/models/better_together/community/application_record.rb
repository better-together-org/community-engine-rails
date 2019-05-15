module BetterTogether
  module Community
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
