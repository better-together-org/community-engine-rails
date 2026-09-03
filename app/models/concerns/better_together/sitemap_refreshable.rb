# frozen_string_literal: true

module BetterTogether
  # Enqueues a scoped sitemap regeneration when a record that appears in the
  # sitemap (see BetterTogether::SitemapHelper) is created, destroyed, or has an
  # SEO-relevant column change committed.
  #
  # The refresh is scoped to the record's own platform so only that tenant's
  # sitemap is rebuilt, and BetterTogether::SitemapRefreshJob.enqueue_unless_pending
  # collapses a burst of edits into a single job per platform.
  module SitemapRefreshable
    extend ActiveSupport::Concern

    # Columns whose change affects what a sitemap contains (URL slug, visibility,
    # publication state). `updated_at` is deliberately excluded — it changes on
    # every save and would defeat the filter.
    SITEMAP_RELEVANT_COLUMNS = %w[slug privacy published_at].freeze

    class << self
      attr_writer :enabled

      # Off in the test environment by default so the whole suite does not enqueue
      # sitemap jobs on every factory build; specs that exercise this behaviour set
      # `BetterTogether::SitemapRefreshable.enabled = true`.
      def enabled?
        @enabled.nil? ? !Rails.env.test? : @enabled
      end
    end

    included do
      after_commit :enqueue_sitemap_refresh, on: %i[create update destroy]
    end

    private

    def enqueue_sitemap_refresh
      return unless BetterTogether::SitemapRefreshable.enabled?
      return unless respond_to?(:platform_id) && platform_id
      return unless sitemap_relevant_change?

      platform = BetterTogether::Platform.find_by(id: platform_id)
      return unless platform&.local_hosted?

      BetterTogether::SitemapRefreshJob.enqueue_unless_pending(platform_id)
    end

    # Always refresh on create/destroy; on update only when an indexed column moved.
    def sitemap_relevant_change?
      return true if destroyed? || previously_new_record?

      SITEMAP_RELEVANT_COLUMNS.any? do |column|
        respond_to?(:"saved_change_to_#{column}?") && public_send(:"saved_change_to_#{column}?")
      end
    end
  end
end
