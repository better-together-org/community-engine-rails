# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes the ShortLink class for JSONAPI
      class ShortLinkResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::ShortLink'

        # Translated attributes
        attributes :title

        # Standard attributes
        attributes :code, :target_url, :status, :expires_at, :click_count

        # Virtual attribute: fully-qualified short URL for the redirect
        attribute :url

        # Relationships
        has_one :creator, class_name: 'Person'

        # Filters
        filter :status
        filter :creator_id
      end
    end
  end
end
