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
      include Searchable

      belongs_to :floor, class_name: 'BetterTogether::Infrastructure::Floor', touch: true
      has_one :building, through: :floor, class_name: 'BetterTogether::Infrastructure::Building'

      delegate :level, to: :floor

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

      def to_s
        name
      end
    end
  end
end
