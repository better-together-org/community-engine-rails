# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI controller for Content::Block (all STI types)
      #
      # Supports listing, reading, creating, updating, and deleting content blocks.
      # Authorization is handled by Content::BlockPolicy via Pundit.
      #
      # Common filters:
      #   GET /api/v1/blocks?filter[page_id]=<uuid>   — all blocks on a page
      #   GET /api/v1/blocks?filter[type]=BetterTogether::Content::AccordionBlock
      #   GET /api/v1/blocks/:id
      #   POST /api/v1/blocks         — body: { data: { type: "blocks", attributes: { type: "...", ... } } }
      #   PATCH /api/v1/blocks/:id
      #   DELETE /api/v1/blocks/:id
      #
      # Creating a block does NOT attach it to a page. To attach, use the page update endpoint
      # with page_blocks_attributes nested params, or use the Rails runner path.
      class BlocksController < BetterTogether::Api::ApplicationController
        def index
          super
        end

        def show
          super
        end

        def create
          super
        end

        def update
          super
        end

        def destroy
          super
        end
      end
    end
  end
end
