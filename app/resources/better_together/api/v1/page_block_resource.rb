# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Content::PageBlock (join model)
      #
      # Represents the ordered association between a Page and a Content::Block.
      # Supports create (attaching a block to a page with optional position),
      # update (reordering), and destroy (detaching).
      class PageBlockResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Content::PageBlock'

        attribute :position

        has_one :page
        has_one :block, class_name: 'ContentBlock'

        filter :page_id

        def self.creatable_fields(_context)
          %i[position page block]
        end

        def self.updatable_fields(_context)
          %i[position]
        end
      end
    end
  end
end
