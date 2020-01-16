module BetterTogether::Community
  # Gathers people and other groups
  class Group < ApplicationRecord
    PRIVACY_LEVELS = {
      secret: 'secret',
      closed: 'closed',
      public: 'public'
    }.freeze

    include FriendlySlug
    include Identity
    include BetterTogetherId

    translates :name
    translates :description, type: :text
    slugged :name

    enum group_privacy: PRIVACY_LEVELS,
         _prefix: :group_privacy


    belongs_to :creator,
              class_name: '::BetterTogether::Community::Person'

    validates :name,
              presence: true
    validates :description,
              presence: true
  end
end
