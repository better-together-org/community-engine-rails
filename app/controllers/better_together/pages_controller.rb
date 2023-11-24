module BetterTogether
  class PagesController < ApplicationController
    before_action :set_page, only: [:show, :edit, :update]

    # GET /better_together/pages
    def index
      @pages = Page.all
    end

    # GET /better_together/pages/:id
    # GET /*path
    def show
      if @page.nil?
        render file: 'public/404.html', status: :not_found, layout: false
      end
    end

    # GET /better_together/pages/new
    def new
      @page = Page.new
    end

    # POST /better_together/pages
    def create
      @page = Page.new(page_params)
      if @page.save
        redirect_to @page, notice: 'Page was successfully created.'
      else
        render :new
      end
    end

    # GET /better_together/pages/:id/edit
    def edit
    end

    # PATCH/PUT /better_together/pages/:id
    def update
      if @page.update(page_params)
        redirect_to @page, notice: 'Page was successfully updated.'
      else
        render :edit
      end
    end

    private

    def set_page
      @page = params[:path].present? ? Page.friendly.find(params[:path]) : Page.friendly.find(params[:id])
    end

    def page_params
      params.require(:page).permit(:title, :slug, :content, :meta_description, :keywords, :published, :published_at, :page_privacy, :layout, :language)
    end
  end
end
