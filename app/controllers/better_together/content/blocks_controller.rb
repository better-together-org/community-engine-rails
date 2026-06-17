# frozen_string_literal: true

module BetterTogether
  module Content
    # Handles CRUD for content blocks independently of pages.
    # rubocop:todo Metrics/ClassLength
    class BlocksController < ResourceController
      ALLOWED_RESOURCE_SEARCH_CLASSES = [
        'BetterTogether::Event',
        'BetterTogether::Checklist',
        'BetterTogether::Community',
        'BetterTogether::Person',
        'BetterTogether::Post'
      ].freeze

      before_action :authenticate_user!
      before_action :disallow_robots
      before_action :set_block, only: %i[show edit update destroy]
      before_action :authorize_preview, only: [:preview_markdown]
      before_action only: %i[index], if: -> { Rails.env.development? } do
        resource_class.load_all_subclasses
      end

      def index
        @blocks = policy_scope(resource_collection)
      end

      def create
        @block = resource_class.new(processed_block_params)
        attach_signed_media(@block)
        authorize_resource

        if @block.save
          redirect_to content_block_path(@block),
                      notice: t('flash.generic.created', resource: t('resources.block'))
        else
          render :new
        end
      end

      def update
        if persist_prepared_block
          respond_to { |format| redirect_after_update(format) }
        else
          respond_to { |format| render_update_errors(format) }
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

      # Allowlist for resource_search: only classes that appear in resource-block views
      # may be resolved. Using a static list instead of safe_constantize prevents
      # attackers from using this endpoint to load arbitrary constants.
      RESOURCE_SEARCH_CLASSES = %w[
        BetterTogether::Community
        BetterTogether::Event
        BetterTogether::Person
        BetterTogether::Post
      ].freeze

      # AJAX endpoint for resource_ids multi-select field in content blocks.
      # Filters available records by resource class and optional search term.
      def resource_search # rubocop:disable Metrics/AbcSize
        authorize resource_class, :resource_search?

        resource_class_name = params[:resource_class].to_s.strip
        search_term = params[:search].to_s.strip

        return render json: [], status: :unprocessable_content unless ALLOWED_RESOURCE_SEARCH_CLASSES.include?(resource_class_name)

        resource_klass = resource_class_name.constantize
        return render json: [], status: :unprocessable_content unless resource_klass.present?

        scope = policy_scope(resource_klass)
        scope = search_scope(scope, search_term) if search_term.present?
        options = scope.limit(50).map { |record| { value: record.id, text: record.to_s } }

        render json: options
      end

      private

      def resolve_resource_class(class_name)
        return unless RESOURCE_SEARCH_CLASSES.include?(class_name)

        class_name.constantize
      end

      def search_scope(scope, search_term)
        # Use Arel to safely construct ILIKE query for translation searches
        translations_table = BetterTogether::StringTranslation.arel_table
        scope.with_translations.where(
          translations_table[:value].matches("%#{search_term}%")
        )
      end

      def block_params # rubocop:todo Metrics/MethodLength
        permitted_params = params.require(:block).permit(
          :type, :media, :identifier, :markdown_source_type, :media_signed_id,
          *resource_class.localized_block_attributes,
          *resource_class.storext_keys
        )

        # Handle markdown_source_type: explicitly clear the unused field so DB values are overwritten
        if permitted_params[:markdown_source_type].present?
          if permitted_params[:markdown_source_type] == 'inline'
            permitted_params[:markdown_file_path] = ''
            permitted_params[:auto_sync_from_file] = false
          elsif permitted_params[:markdown_source_type] == 'file'
            permitted_params.delete(:markdown_source)
          end
          permitted_params.delete(:markdown_source_type) # Remove the helper param
        end

        permitted_params
      end

      def permitted_block_attributes
        [
          :type,
          :media,
          :identifier,
          :markdown_source_type,
          *resource_class.localized_block_attributes,
          *resource_class.storext_keys,
          *resource_class.extra_permitted_attributes
        ]
      end

      def processed_block_params
        block_params.except(:media_signed_id)
      end

      def persist_prepared_block
        @block.assign_attributes(processed_block_params)
        attach_signed_media(@block)
        @block.save
      end

      def redirect_after_update(format)
        notice = t('flash.generic.updated', resource: t('resources.block'))

        format.html { redirect_to content_block_path(@block), notice: }
        format.turbo_stream { redirect_to content_block_path(@block), notice: }
      end

      def render_update_errors(format)
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(helpers.dom_id(@block, 'form'), partial: 'form',
                                                                                    locals: { block: @block }),
                 status: :unprocessable_entity
        end
        format.html { render :edit, status: :unprocessable_entity }
      end

      def set_block
        @block = set_resource_instance
      end

      def attach_signed_media(record)
        signed_id = params.dig(:block, :media_signed_id)
        record.media.attach(signed_id) if signed_id.present?
      end

      def resource_class
        BetterTogether::Content::Block
      end

      def resource_collection
        super.with_translations
      end

      def authorize_preview
        authorize(resource_class, :preview_markdown?)
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
