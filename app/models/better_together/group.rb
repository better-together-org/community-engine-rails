module BetterTogether
  # Gathers people and other groups
  class Group < ApplicationRecord
    PRIVACY_LEVELS = {
      secret: 'secret',
      closed: 'closed',
      public: 'public'
    }.freeze

    include AuthorConcern
    include FriendlySlug
    include Identity

    translates :name
    translates :description, type: :text
    slugged :name

    enum group_privacy: PRIVACY_LEVELS,
         _prefix: :group_privacy

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
