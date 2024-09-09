# frozen_string_literal: true

module BetterTogether
  module Content
    # CRUD for content blocks independently of pages
    class BlocksController < ApplicationController
      before_action :authenticate_user!
      before_action :set_block, only: %i[show edit update destroy]
      before_action only: %i[index], if: -> { Rails.env.development? } do
        # Make sure that all BLock subclasses are loaded in dev to generate new block buttons
        BetterTogether::Content::Block.load_all_subclasses
      end

      def index
        @blocks = BetterTogether::Content::Block.includes(:pages).all
      end

      def create
        @block = BetterTogether::Content::Block.new(block_params)

        if @block.save
          redirect_to content_block_path(@block), notice: 'Block was successfully created.'
        else
          render :new
        end
      end

      def update
        respond_to do |format|
          if @block.update(block_params)
            redirect_to edit_content_block_path(@block), notice: 'Block was successfully updated.'
          else
            format.turbo_stream do
              render turbo_stream: turbo_stream.replace(helpers.dom_id(@block, 'form'), partial: 'form',
                                                                                        locals: { block: @block })
            end
          end
        end
      end

      def new
        @block = BetterTogether::Content::Block.new(type: params[:block_type])

        respond_to(&:html)
      end

      def destroy
        @block.destroy unless @block.pages.any?

        redirect_to content_blocks_path, notice: 'Block was sucessfully deleted'
      end

      private

      def block_params
        params.require(:block).permit(
          :type, :media, :identifier,
          *BetterTogether::Content::Block.localized_block_attributes,
          *BetterTogether::Content::Block.storext_definitions.keys
        )
      end

      def set_block
        @block = BetterTogether::Content::Block.find(params[:id])
      end
    end
  end
end
