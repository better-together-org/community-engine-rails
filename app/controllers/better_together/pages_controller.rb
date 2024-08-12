# frozen_string_literal: true

module BetterTogether
  # Responds to requests for pages
  class PagesController < FriendlyResourceController
    before_action :set_page, only: %i[show edit update destroy]

    def index
      authorize resource_class
      @pages = policy_scope(resource_class.with_translations)
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

    protected

    def id_param
      path = params[:path]

      # if path.nil?
      #   I18n.locale = I18n.default_locale
      #   id_param = 'home-page'
      # end

      id_param = path.present? ? path : super
    end

    def handle_404
      raise 'error'
      path = params[:path]

      # If page is not found and the path is one of the variants of the root path, render community engine promo page
      if ['home-page', "/#{I18n.locale}/", "/#{I18n.locale}", I18n.locale.to_s, 'bt', '/'].include?(path)
        render 'better_together/static_pages/community_engine'
      else
        render_404
      end
    end

    private

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

    # rubocop:todo Metrics/PerceivedComplexity
    # rubocop:todo Metrics/MethodLength
    # rubocop:todo Metrics/AbcSize
    def set_page # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      @page = set_resource_instance
    rescue ActiveRecord::RecordNotFound
      handle_404
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/PerceivedComplexity

    def page_params
      params.require(:page).permit(:meta_description, :keywords, :published, :published_at,
                                   :privacy, :layout, :template, *locale_attributes)
    end

    def locale_attributes
      localized_attributes = BetterTogether::Page.mobility_attributes.map do |attribute|
        I18n.available_locales.map do |locale|
          :"#{attribute}_#{locale}"
        end
      end

      localized_attributes.flatten
    end

    def resource_class
      ::BetterTogether::Page
    end
  end
end
