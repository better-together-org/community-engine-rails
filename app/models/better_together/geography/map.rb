# frozen_string_literal: true

module BetterTogether
  module Geography
    # Spatial representations of data
    class Map < ApplicationRecord
      include Creatable
      include FriendlySlug
      include Identifier
      include Privacy
      include Protected
      include Searchable
      include Viewable

      slugged :title

      translates :title
      translates :description, backend: :action_text

      settings index: { number_of_shards: 1 } do
        mappings dynamic: 'false' do
          indexes :title, as: 'title'
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
        title
      end
    end
  end
end
