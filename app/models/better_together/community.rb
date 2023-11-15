module BetterTogether
  # A gathering
  class Community < ApplicationRecord
    PRIVACY_LEVELS = {
      secret: 'secret',
      closed: 'closed',
      public: 'public'
    }.freeze

    include FriendlySlug

    translates :name
    translates :description, type: :text
    slugged :name

    enum privacy: PRIVACY_LEVELS,
         _prefix: :privacy

    belongs_to :creator,
              class_name: '::BetterTogether::Person'

    validates :name,
              presence: true
    validates :description,
              presence: true

    def to_s
      name
    end
  end
end
