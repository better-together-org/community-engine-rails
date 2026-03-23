# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    # Represents Floors in a Building
    class Floor < ApplicationRecord
      include Contactable
      include Creatable
      include Identifier
      include FriendlySlug
      include Geography::Geospatial::One
      include Positioned
      include Privacy
      include PrimaryCommunity

      has_community

      after_create :ensure_room

      belongs_to :building, class_name: 'BetterTogether::Infrastructure::Building', touch: true
      has_many :rooms, class_name: 'BetterTogether::Infrastructure::Room', dependent: :destroy

      translates :name, type: :string
      translates :description, backend: :action_text

      slugged :name

      validates :level,
                numericality: { only_integer: true },
                uniqueness: { scope: %i[building_id] },
                presence: true

      def ensure_room
        return if rooms.size.positive?

        rooms.create(name: 'Main')
      end

      def to_s
        name
      end
    end
  end
end
