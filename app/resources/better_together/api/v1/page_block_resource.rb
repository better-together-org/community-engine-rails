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
        has_one :block, class_name: 'Block'

        filter :page_id

        # Override destroy to use SQL delete rather than ActiveRecord destroy,
        # avoiding the belongs_to :block, dependent: :destroy cascade.
        # Destroying the underlying block is handled via BlockResource directly.
        # Must return :completed — JSONAPI-Resources 0.10 maps :completed → 204,
        # anything else → 202. (See jsonapi/processor.rb destroy operation.)
        def _remove
          _model.delete
          :completed
        end

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
