# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    class Building < Structure
      include Contactable
      include Creatable
      include Identifier
      include FriendlySlug
      include Geography::Geospatial::One
      include Privacy
      include PrimaryCommunity
      include Searchable

      after_create :ensure_floor

      has_many :floors,
               -> { order(:level) },
               class_name: 'BetterTogether::Infrastructure::Floor',
               dependent: :destroy
      has_many :rooms,
               through: :floors,
               class_name: 'BetterTogether::Infrastructure::Room',
               dependent: :destroy

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

      def ensure_floor
        return if floors.size.positive?

        floors.create(name: 'Ground')
      end

      def to_s
        name
      end
    end
  end
end
