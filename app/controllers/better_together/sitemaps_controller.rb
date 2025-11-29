# frozen_string_literal: true

module BetterTogether
  # Serves the generated sitemap stored in Active Storage
  class SitemapsController < ApplicationController
    def show
      sitemap = Sitemap.current(helpers.host_platform)
      if sitemap.file.attached?
        redirect_to sitemap.file.url, allow_other_host: true
      else
        head :not_found
      end
    end
  end
end
