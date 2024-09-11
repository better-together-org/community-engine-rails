# frozen_string_literal: true

module BetterTogether
  module Content
    # CRUD for page blocks
    class PageBlocksController < ApplicationController
      before_action :authenticate_user!
      before_action :set_page

      def new
        @page_block = @page.page_blocks.build

        @page_block.build_block(type: params[:block_type]) # Build the new PageBlock and associated Block

        respond_to do |format|
          format.html
          format.turbo_stream do
            render turbo_stream: turbo_stream.append('blocks-list',
                                                     # rubocop:todo Layout/LineLength
                                                     partial: 'better_together/content/page_blocks/form_fields', locals: { page_block: @page_block })
            # rubocop:enable Layout/LineLength
          end
        end
      end

      def destroy # rubocop:todo Metrics/AbcSize
        @page_block = @page.page_blocks.find_by(id: params[:id]) || @page.page_blocks.build
        @page_block.destroy if @page_block.persisted?

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.remove(helpers.dom_id(@page_block, params[:id]))
          end
        end
      end

      private

      def form_for_page_block(page_block)
        view_context.form_with(model: [page_block.page, page_block], url: new_page_page_block_path(page_block.page),
                               local: true)
      end

      def set_page
        @page = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(
          translatable_type: 'BetterTogether::Page',
          key: 'slug',
          value: params[:page_id],
          locale: I18n.available_locales
        ).includes(:translatable).last&.translatable
      end
    end
  end
end
