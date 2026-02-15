# frozen_string_literal: true

module BetterTogether
  # Concern that triggers sitemap regeneration when a record that appears
  # in the sitemap is created, updated, or destroyed. Include this in any
  # model whose public instances are listed in the sitemap (Page, Post,
  # Event, Community, etc.).
  module SitemapRefreshable
    extend ActiveSupport::Concern

    included do
      after_commit :refresh_sitemap, on: %i[create update destroy]
    end

    private

    def refresh_sitemap
      return if Rails.env.test?

      BetterTogether::SitemapRefreshJob.perform_later
    end
  end
end
