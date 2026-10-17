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

        # Categories by identifier (unknown identifiers are rejected)
        attribute :category_identifiers

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

        # A backfill or import sends created_at on create to keep the original date, and updated_at on create or update
        # to set it back (saving blocks and the cover touches the record, see Post#apply_pinned_updated_at).
        def created_at=(value)
          _model.created_at = value
          _model.updated_at = value
          _model.pin_timestamps_to_creation = true
        end

        def updated_at=(value)
          _model.updated_at = value
          _model.pinned_updated_at = value
        end

        # Creatable and updatable fields. created_at is create-only: it is never rewritten afterwards.
        def self.creatable_fields(context)
          super - %i[slug cover_image_url published_at] + %i[category_identifiers created_at updated_at]
        end

        def self.updatable_fields(context)
          creatable_fields(context) - %i[created_at]
        end
      end
    end
  end
end
