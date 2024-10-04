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

        # Dispatch the background job for tracking the page view
        BetterTogether::Metrics::TrackPageViewJob.perform_later(@page, I18n.locale.to_s) unless bot_request?
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
        redirect_to edit_page_path(@page), notice: 'Page was successfully created.'
      else
        render :new
      end
    end

    def edit
      authorize @page
    end

    def update
      authorize @page

      respond_to do |format|
        if @page.update(page_params)
          format.html do
            flash[:notice] = 'Page was successfully updated.'
            redirect_to edit_page_path(@page), notice: 'Page was successfully updated.'
          end
          format.turbo_stream do
            flash.now[:notice] = 'Page was successfully updated.'
            render turbo_stream: [
              turbo_stream.replace(helpers.dom_id(@page, 'form'), partial: 'form',
                                                                                      locals: { page: @page }),
              turbo_stream.replace('flash_messages', partial: 'layouts/better_together/flash_messages',
                                                                                      locals: { flash: })
            ]
          end
        else
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(helpers.dom_id(@page, 'form'), partial: 'form',
                                                                                      locals: { page: @page })
          end
        end
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
        *Page.extra_permitted_attributes,
        page_blocks_attributes: [
          :id, :position, :_destroy,
          {
            block_attributes: [
              :id, :type, :identifier, :_destroy,
              *BetterTogether::Content::Block.localized_block_attributes,
              *BetterTogether::Content::Block.storext_keys,
              *BetterTogether::Content::Block.extra_permitted_attributes
            ]
          }
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
