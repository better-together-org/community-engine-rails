# frozen_string_literal: true

module BetterTogether
  # Responds to requests for pages
  class PagesController < ApplicationController
    before_action :set_page, only: %i[show edit update destroy]

    def index
      authorize ::BetterTogether::Page
      @pages = policy_scope(::BetterTogether::Page.with_translations)
    end

    def show
      if @page.nil?
        render file: 'public/404.html', status: :not_found, layout: false
      else
        authorize @page
        @layout = 'layouts/better_together/page'
        @layout = @page.layout if @page.layout.present?
      end
    end

    def new
      @page = ::BetterTogether::Page.new
      authorize @page
    end

    def create
      @page = ::BetterTogether::Page.new(page_params)
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
        redirect_to safe_page_redirect_url, notice: 'Page was successfully updated.'
      else
        render :edit
      end
    end

    def destroy
      authorize @page
      @page.destroy
      redirect_to pages_url, notice: 'Page was successfully destroyed.'
    end

    private

    def page
      path = params[:path]
      id_param = path.present? ? path : params[:id]

      @page ||= ::BetterTogether::Page.friendly.find(id_param)
    end
    
    def safe_page_redirect_url
      if page
        url = url_for(page)
        return url if url.start_with?(root_url)
      end

      root_url # Fallback to a safe URL if the original is not safe
    end

    def set_page
      path = params[:path]
      id_param = path.present? ? path : params[:id]

      @page = ::BetterTogether::Page.friendly.find(id_param)
      authorize @page if @page
    rescue ActiveRecord::RecordNotFound
      path = params[:path]

      render 'errors/404', status: :not_found unless ['bt', '/'].include?(path) # && return

      render 'better_together/static_pages/community_engine'
    end

    def page_params
      params.require(:page).permit(:title, :slug, :content, :meta_description, :keywords, :published, :published_at,
                                   :privacy, :layout, :language)
    end
  end
end
