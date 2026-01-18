# frozen_string_literal: true

module BetterTogether
  module Content
    # CRUD for content blocks independently of pages
    class BlocksController < ResourceController
      before_action :authenticate_user!
      before_action :disallow_robots
      before_action :set_block, only: %i[show edit update destroy]
      before_action :authorize_preview, only: [:preview_markdown]
      before_action only: %i[index], if: -> { Rails.env.development? } do
        # Make sure that all BLock subclasses are loaded in dev to generate new block buttons
        resource_class.load_all_subclasses
      end

      def index
        @blocks = policy_scope(resource_collection)
      end

      def create
        @block = resource_instance(block_params)
        authorize_resource

        if @block.save
          redirect_to content_block_path(@block),
                      notice: t('flash.generic.created', resource: t('resources.block'))
        else
          render :new
        end
      end

      def update # rubocop:todo Metrics/MethodLength
        respond_to do |format|
          if @block.update(block_params)
            redirect_to content_block_path(@block),
                        notice: t('flash.generic.updated', resource: t('resources.block'))
          else
            format.turbo_stream do
              render turbo_stream: turbo_stream.replace(helpers.dom_id(@block, 'form'), partial: 'form',
                                                                                        locals: { block: @block })
            end
          end
        end
      end

      def new
        @block = resource_class.new(type: params[:block_type])

        respond_to(&:html)
      end

      def destroy
        @block.destroy unless @block.pages.any?

        redirect_to content_blocks_path, notice: t('flash.generic.destroyed', resource: t('resources.block'))
      end

      def preview_markdown # rubocop:todo Metrics/MethodLength
        markdown_content = params[:markdown]

        if markdown_content.blank?
          render json: { html: '<p class="text-muted mb-0"><em>Preview will appear here...</em></p>' }
          return
        end

        begin
          rendered_html = MarkdownRendererService.new(markdown_content).render_html
          render json: { html: rendered_html }
        rescue StandardError => e
          Rails.logger.error "Markdown preview error: #{e.message}"
          render json: {
            html: '<div class="alert alert-warning mb-0"><i class="fa fa-exclamation-triangle"></i> ' \
                  'Failed to render preview. Please check your markdown syntax.</div>'
          }, status: :unprocessable_entity
        end
      end

      private

      def block_params
        permitted_params = params.require(:block).permit(
          :type, :media, :identifier, :markdown_source_type,
          *resource_class.localized_block_attributes,
          *resource_class.storext_keys
        )

        # Handle markdown_source_type: clear the unused field
        if permitted_params[:markdown_source_type].present?
          if permitted_params[:markdown_source_type] == 'inline'
            permitted_params.delete(:markdown_file_path)
          elsif permitted_params[:markdown_source_type] == 'file'
            permitted_params.delete(:markdown_source)
          end
          permitted_params.delete(:markdown_source_type) # Remove the helper param
        end

        permitted_params
      end

      def set_block
        @block = set_resource_instance
      end

      def resource_class
        BetterTogether::Content::Block
      end

      def authorize_preview
        authorize(resource_class, :preview_markdown?)
      end
    end
  end
end
