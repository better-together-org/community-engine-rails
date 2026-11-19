# frozen_string_literal: true

module BetterTogether
  # Links and labels for the background jobs tab and summary panel.
  module HostJobsHelper
    SIDEKIQ_PAGES = { dashboard: '', busy: 'busy', queues: 'queues', retries: 'retries', dead: 'morgue',
                      scheduled: 'scheduled' }.freeze

    def host_jobs_visible?
      BetterTogether::HostJobsPolicy.new(current_user, :host_jobs).show?
    end

    # Sidekiq page URL with the current locale, which SidekiqWebLocale maps onto Sidekiq's own.
    def sidekiq_web_url_for(page = :dashboard)
      "#{better_together.sidekiq_web_path(locale: nil)}/#{SIDEKIQ_PAGES.fetch(page)}?#{{ locale: I18n.locale }.to_query}"
    end

    # A count that opens its Sidekiq page: inside the embedded frame on the jobs tab, the whole window
    # elsewhere. Turbo is off because Sidekiq pages are not Turbo responses.
    def host_jobs_sidekiq_link(key, value, page, context:)
      options = { id: "host-jobs-#{key}-link", class: 'host-jobs-summary-link', data: { turbo: false },
                  'aria-label': t("host_dashboard.jobs.summary.links.#{key}", count: value) }
      options[:target] = 'host-jobs-sidekiq-iframe' if context == 'tab'
      link_to number_with_delimiter(value), sidekiq_web_url_for(page), **options
    end

    def host_jobs_latency(seconds)
      return t('host_dashboard.jobs.summary.no_latency') if seconds.to_f <= 0

      distance_of_time_in_words(seconds.to_f.seconds)
    end
  end
end
