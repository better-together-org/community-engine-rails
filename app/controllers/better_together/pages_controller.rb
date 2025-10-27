# frozen_string_literal: true

module BetterTogether
  # Responds to requests for pages
  class PagesController < FriendlyResourceController # rubocop:todo Metrics/ClassLength
    before_action :set_page, only: %i[show edit update destroy]

    skip_before_action :check_platform_setup, unless: -> { ::BetterTogether::Platform.where(host: true).any? }

    before_action only: %i[new edit], if: -> { Rails.env.development? } do
      # Make sure that all BLock subclasses are loaded in dev to generate new block buttons
      BetterTogether::Content::Block.load_all_subclasses
    end

    def index
      authorize resource_class

      @pages = build_filtered_collection
      @pages = apply_sorting(@pages)
      @pages = @pages.page(params[:page]).per(25)
    end

    def show
      # Hide pages that don't exist or aren't viewable to the current user as 404s
      render_not_found and return if @page.nil?

      # Preload content blocks with their associations for better performance
      @content_blocks = @page.content_blocks.includes(
        background_image_file_attachment: :blob
      )
      @layout = 'layouts/better_together/page'
      @layout = @page.layout if @page.layout.present?
    end

    def new
      @page = resource_class.new
      authorize @page
    end

    def create # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      @page = resource_class.new(page_params)
      authorize @page

      BetterTogether::Authorship.with_creator(helpers.current_person) do
        respond_to do |format|
          if @page.save
            format.html do
              redirect_to edit_page_path(@page), notice: t('flash.generic.created', resource: t('resources.page'))
            end
            format.turbo_stream do
              flash.now[:notice] = t('flash.generic.created', resource: t('resources.page'))
              render turbo_stream: turbo_stream.redirect_to(edit_page_path(@page))
            end
          else
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @page }
              )
            end
            format.html { render :new, status: :unprocessable_entity }
          end
        end
      end
    end

    def edit
      authorize @page
    end

    def update # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      authorize @page

      BetterTogether::Authorship.with_creator(helpers.current_person) do # rubocop:todo Metrics/BlockLength
        respond_to do |format| # rubocop:todo Metrics/BlockLength
          if @page.update(page_params)
            format.html do
              flash[:notice] = t('flash.generic.updated', resource: t('resources.page'))
              redirect_to edit_page_path(@page), notice: t('flash.generic.updated', resource: t('resources.page'))
            end
            format.turbo_stream do
              flash.now[:notice] = t('flash.generic.updated', resource: t('resources.page'))
              render turbo_stream: [
                turbo_stream.replace(helpers.dom_id(@page, 'form'), partial: 'form',
                                                                    locals: { page: @page }),
                turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                       locals: { flash: })
              ]
            end
          else
            format.html { render :edit }
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.replace(helpers.dom_id(@page, 'form'), partial: 'form', locals: { page: @page }),
                turbo_stream.update(
                  'form_errors',
                  partial: 'layouts/better_together/errors',
                  locals: { object: @page }
                )
              ]
            end
          end
        end
      end
    end

    def destroy
      authorize @page
      @page.destroy
      redirect_to pages_url, notice: t('flash.generic.destroyed', resource: t('resources.page'))
    end

    protected

    def id_param
      path = params[:path]

      path.present? ? path : super
    end

    private

    def render_not_found
      path = params[:path]

      # If page is not found and the path is one of the variants of the root path, render community engine promo page
      if ['home-page', 'home', "/#{I18n.locale}/", "/#{I18n.locale}", I18n.locale.to_s, 'bt', '/'].include?(path)
        render 'better_together/static_pages/community_engine'
      else
        super
      end
    end

    def page
      @page ||= set_page
    end

    def safe_page_redirect_url
      if page
        url = url_for(page)
        return url if url.start_with?(helpers.base_url)
      end

      helpers.base_url # Fallback to a safe URL if the original is not safe
    end

    def set_page
      @page = set_resource_instance
      return unless @page

      @page = preload_page_associations(@page)
    rescue ActiveRecord::RecordNotFound
      render_not_found && return
    end

    def resource_class
      ::BetterTogether::Page
    end

    def resource_collection
      policy_scope(resource_class)
    end

    def apply_sorting(collection)
      sort_by = params[:sort_by]
      sort_direction = params[:sort_direction] == 'desc' ? :desc : :asc

      case sort_by
      when 'title', 'slug'
        collection.i18n.order(sort_by.to_sym => sort_direction)
      else
        collection.order(collection.arel_table[:identifier].send(sort_direction))
      end
    end

    def build_filtered_collection
      collection = base_collection
      collection = apply_title_filter(collection) if params[:title_filter].present?
      collection = apply_slug_filter(collection) if params[:slug_filter].present?
      collection
    end

    def translatable_conditions
      []
    end

    def base_collection
      resource_collection.includes(
        :string_translations,
        page_blocks: {
          block: [{ background_image_file_attachment: :blob }]
        }
      )
    end

    def apply_title_filter(collection)
      search_term = params[:title_filter].strip
      collection.i18n { title.matches("%#{search_term}%") }
    end

    def apply_slug_filter(collection)
      search_term = params[:slug_filter].strip
      collection.i18n { slug.matches("%#{search_term}%") }
    end

    def preload_page_associations(page)
      resource_class.includes(page_includes).find(page.id)
    end

    def page_includes
      [
        :string_translations,
        :sidebar_nav,
        { page_blocks: {
          block: [{ background_image_file_attachment: :blob }]
        } }
      ]
    end

    def page_params
      params.require(:page).permit(
        basic_page_attributes + page_blocks_permitted_attributes
      )
    end

    def basic_page_attributes
      [
        :meta_description, :keywords, :published_at, :sidebar_nav_id,
        :privacy, :layout, :template, *Page.localized_attribute_list,
        *Page.extra_permitted_attributes
      ]
    end

    def page_blocks_permitted_attributes
      [
        page_blocks_attributes: [
          :id, :position, :_destroy,
          { block_attributes: block_permitted_attributes }
        ]
      ]
    end

    def block_permitted_attributes
      [
        :id, :type, :identifier, :_destroy,
        *BetterTogether::Content::Block.localized_block_attributes,
        *BetterTogether::Content::Block.storext_keys,
        *BetterTogether::Content::Block.extra_permitted_attributes
      ]
    end
  end
end
