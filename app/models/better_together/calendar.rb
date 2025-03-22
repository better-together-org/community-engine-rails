# frozen_string_literal: true

module BetterTogether
  # Calendar management and display
  class Calendar < ApplicationRecord
    include Creatable
    include FriendlySlug
    include Identifier
    include Privacy
    include Protected
    include Searchable
    include Viewable

    belongs_to :community, class_name: '::BetterTogether::Community'

    slugged :name

    translates :name
    translates :description, backend: :action_text

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
