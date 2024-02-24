# frozen_string_literal: true

module BetterTogether
  # Prevents deleting important built-in seed data like default pages
  module Protected
    extend ActiveSupport::Concern

    included do
      validates :protected, inclusion: { in: [true, false] }
    end

    def protected?
      protected
    end
  end
end
