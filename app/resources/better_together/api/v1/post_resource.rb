# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes the Post class for JSONAPI
      class PostResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Post'

        # Translated attributes
        attributes :title, :content

        # Standard attributes
        attributes :slug, :identifier, :privacy,
                   :published_at

        # Virtual attributes for attachments
        attribute :cover_image_url

        # Relationships
        has_one :creator, class_name: 'Person'

        # Filters
        filter :privacy
        filter :creator_id

        # Custom attribute methods
        def cover_image_url
          attachment_url(:cover_image)
        end

        # Creatable and updatable fields
        def self.creatable_fields(context)
          super - %i[slug cover_image_url published_at]
        end

        def self.updatable_fields(context)
          creatable_fields(context)
        end
      end
    end
  end
end
