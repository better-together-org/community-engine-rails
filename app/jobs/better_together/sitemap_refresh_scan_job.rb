# frozen_string_literal: true

module BetterTogether
  # Scheduled sweep that enqueues a scoped SitemapRefreshJob for every
  # locally-hosted platform. Runs from sidekiq-cron (see config/sidekiq_scheduler.yml)
  # so every tenant's sitemap is regenerated on a regular cadence even if its
  # content has not changed enough to trigger an on-commit refresh.
  class SitemapRefreshScanJob < ApplicationJob
    queue_as :maintenance

    def perform
      BetterTogether::Platform.internal.find_each do |platform|
        BetterTogether::SitemapRefreshJob.enqueue_unless_pending(platform.id)
      end
    end
  end
end
