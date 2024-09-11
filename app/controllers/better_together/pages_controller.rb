# frozen_string_literal: true

module BetterTogether
  # Responds to requests for pages
  class PagesController < FriendlyResourceController
    before_action :set_page, only: %i[show edit update destroy]

    before_action only: %i[new edit], if: -> { Rails.env.development? } do
      # Make sure that all BLock subclasses are loaded in dev to generate new block buttons
      BetterTogether::Content::Block.load_all_subclasses
    end

    def index
      authorize resource_class
      @pages = policy_scope(resource_class.with_translations)
    end

    def show
      if @page.nil? || !@page.published?
        render_404
      else
        authorize @page
        @layout = 'layouts/better_together/page'
        @layout = @page.layout if @page.layout.present?
      end
    end

    def new
      @page = resource_class.new
      authorize @page
    end

    def create
      @page = resource_class.new(page_params)
      authorize @page

      if @page.save
        redirect_to safe_page_redirect_url, notice: 'Page was successfully created.'
      else
        render :new
      end
    end

    def edit
      authorize @page
    end

    def update
      authorize @page

      if @page.update(page_params)
        redirect_to edit_page_path(@page), notice: 'Page was successfully updated.'
      else
        render :edit
      end
    end

    def destroy
      authorize @page
      @page.destroy
      redirect_to pages_url, notice: 'Page was successfully destroyed.'
    end

    protected

    def id_param
      path = params[:path]

      # if path.nil?
      #   I18n.locale = I18n.default_locale
      #   id_param = 'home-page'
      # end

      path.present? ? path : super
    end

    private

    def handle404
      path = params[:path]

      # If page is not found and the path is one of the variants of the root path, render community engine promo page
      if ['home-page', "/#{I18n.locale}/", "/#{I18n.locale}", I18n.locale.to_s, 'bt', '/'].include?(path)
        render 'better_together/static_pages/community_engine'
      else
        render_404
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
    rescue ActiveRecord::RecordNotFound
      handle404
    end

    def page_params # rubocop:todo Metrics/MethodLength
      params.require(:page).permit(
        :meta_description, :keywords, :published_at,
        :privacy, :layout, :template, *Page.localized_attribute_list,
        page_blocks_attributes: [
          :id, :position, :_destroy,
          { block_attributes: [
            :id, :type, :media, :identifier, :_destroy,
            *BetterTogether::Content::Block.localized_block_attributes,
            *BetterTogether::Content::Block.storext_definitions.keys
          ] }
        ]
      )
    end

    def resource_class
      ::BetterTogether::Page
    end

    def resource_collection
      resource_class.published
    end

    def translatable_conditions
      []
    end
  end
end
