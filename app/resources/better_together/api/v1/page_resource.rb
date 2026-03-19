# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Page
      # Exposes published pages with content blocks
      class PageResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Page'

        # Translated attributes
        translatable_attribute :title

        # Regular attributes
        attributes :slug, :privacy, :layout, :published_at
        attribute :show_title
        attribute :content_excerpt

        # Relationships
        has_one :community
        has_one :creator, class_name: 'Person'
        has_many :page_blocks, class_name: 'PageBlock'
        has_many :blocks, class_name: 'ContentBlock'

        # Filters
        filter :privacy
        filter :layout
        filter :slug

        def content_excerpt
          @model.content&.to_plain_text&.truncate(200)
        end

        def show_title
          @model.show_title
        end

        def self.creatable_fields(_context)
          %i[title content privacy layout show_title community]
        end

        def self.updatable_fields(_context)
          %i[title content privacy layout show_title published_at]
        end
      end
    end
  end
end
