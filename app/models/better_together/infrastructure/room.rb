# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    # Represents rooms on a floor in a building
    class Room < ApplicationRecord
      include Contactable
      include Creatable
      include Identifier
      include FriendlySlug
      include Geography::Geospatial::One
      include Privacy
      include PrimaryCommunity

      belongs_to :floor, class_name: 'BetterTogether::Infrastructure::Floor', touch: true
      has_one :building, through: :floor, class_name: 'BetterTogether::Infrastructure::Building'

      delegate :level, to: :floor

      translates :name
      translates :description, backend: :action_text

      slugged :name

      def to_s
        name
      end
    end
  end
end
