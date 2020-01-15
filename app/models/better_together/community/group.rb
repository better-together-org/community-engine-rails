module BetterTogether::Community
  class Group < ApplicationRecord
      include FriendlySlug
      include Identity
      include BetterTogetherId

      slugged :name

      belongs_to :creator,
                class_name: '::BetterTogether::Community::Person'

      validates :name,
                presence: true
      validates :description,
                presence: true
  end
end
