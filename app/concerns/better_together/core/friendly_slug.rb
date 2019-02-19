
module BetterTogether
   module Core
    module FriendlySlug
      extend ActiveSupport::Concern

      included do
        extend ::FriendlyId

        validates :slug, presence: true

        def self.slugged(attr)
          friendly_id attr, use: :slugged
        end
      end
    end
  end
end
