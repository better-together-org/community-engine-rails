module BetterTogether
  module Core
    class Person < ApplicationRecord

      validates :given_name,
                presence: true
    end
  end
end
