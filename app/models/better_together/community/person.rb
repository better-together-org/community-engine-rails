module BetterTogether
  module Community
    class Person < ApplicationRecord
      include FriendlySlug
      include Identity
      include BetterTogetherId

      slugged :full_name

      validates :given_name,
                presence: true

      def full_name
        [given_name, family_name].compact.join(' ')
      end
    end
  end
end
