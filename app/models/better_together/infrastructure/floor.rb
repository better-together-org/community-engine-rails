# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    class Floor < ApplicationRecord
      include Contactable
      include Creatable
      include Identifier
      include FriendlySlug
      include Geography::Geospatial::One
      include Positioned
      include Privacy
      include PrimaryCommunity
      include Searchable

      after_create :ensure_room

      belongs_to :building, class_name: 'BetterTogether::Infrastructure::Building', touch: true
      has_many :rooms, class_name: 'BetterTogether::Infrastructure::Room', dependent: :destroy

      translates :name
      translates :description, backend: :action_text

      slugged :name

      settings index: { number_of_shards: 1 } do
        mappings dynamic: 'false' do
          indexes :name, as: 'name'
          indexes :description, as: 'description'
          indexes :rich_text_content, type: 'nested' do
            indexes :body, type: 'text'
          end
          indexes :rich_text_translations, type: 'nested' do
            indexes :body, type: 'text'
          end
        end
      end

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
