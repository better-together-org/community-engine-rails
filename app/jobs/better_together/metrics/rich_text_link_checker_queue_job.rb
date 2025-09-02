# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Base queueing job that distributes RichText link check work across hosts.
    # It groups RichText links by host and schedules child jobs with delays to
    # avoid overloading external hosts or the application.
    class RichTextLinkCheckerQueueJob < MetricsJob
      def perform
        records_size = model_collection.size
        return if records_size.zero?

        # Define the total time window for each host (e.g., 1 hour in seconds)
        time_window = 3600

        records_by_host.each do |host, link_count|
          next if link_count.zero?

          delay_between_requests = time_window / link_count.to_f
          queue_jobs_for_host(host, delay_between_requests)
        end
      end

      def records_by_host
        model_collection.group(:host)
                        .order('count_all DESC')
                        .count
      end

      protected

      def model_class
        BetterTogether::Metrics::RichTextLink
      end

      def model_collection
        # Select links that either haven't been checked yet (last_checked_at IS NULL)
        # or were last checked before the configured threshold. Don't restrict to
        # only "valid_link" records because we want to re-check previously
        # invalidated links as well.
        model_class.where('last_checked_at IS NULL OR last_checked_at < ?', last_checked_lt)
      end

      def queue_jobs_for_host(host, delay_between_requests)
        links_for_host = model_collection.where(host: host)
        links_for_host.each_with_index do |link, index|
          schedule_time = Time.current + (delay_between_requests * index).seconds
          child_job_class.set(wait_until: schedule_time).perform_later(link.id)
        end
      end

      def child_job_class
        # Define this in subclasses (e.g., InternalLinkCheckerJob, ExternalLinkCheckerJob)
        raise NotImplementedError, 'Subclasses must implement `child_job_class`'
      end

      def last_checked_lt
        Time.current - last_checked_threshold
      end

      def last_checked_threshold
        14.days
      end
    end
  end
end
