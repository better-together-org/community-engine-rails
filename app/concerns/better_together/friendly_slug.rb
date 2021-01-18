
module BetterTogether
  module FriendlySlug
    extend ActiveSupport::Concern

    included do
      extend Mobility
      extend ::FriendlyId
      translates :slug

      validates :slug, presence: true

      # This method must be called or the class will have validation issues
      def self.slugged(attribute)
        friendly_id(
          attribute,
          use: %i[slugged history mobility]
        )
      end
    end
  end
end
