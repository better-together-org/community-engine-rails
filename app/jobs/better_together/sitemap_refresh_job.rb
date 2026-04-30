# frozen_string_literal: true

require 'rake'
require 'sidekiq/api'

module BetterTogether
  # Generates the sitemap in a background job so newly published pages are included
  class SitemapRefreshJob < ApplicationJob
    queue_as :default

    class << self
      def enqueue_unless_pending
        return perform_later unless pending?

        false
      end

      def pending?
        enqueued? || running?
      end

      private

      def enqueued?
        Sidekiq::Queue.new(queue_name).any? do |job|
          wrapped_job_class(job.item) == name
        end
      rescue StandardError
        false
      end

      def running?
        Sidekiq::Workers.new.any? do |_process_id, _thread_id, work|
          wrapped_job_class(work.respond_to?(:job) ? work.job : work) == name
        end
      rescue StandardError
        false
      end

      def wrapped_job_class(payload)
        return unless payload.is_a?(Hash)

        payload['wrapped'] || payload['class']
      end
    end

    def perform
      Rails.application.load_tasks unless Rake::Task.task_defined?('sitemap:refresh')
      Rake::Task['sitemap:refresh'].invoke
      Rake::Task['sitemap:refresh'].reenable
    end
  end
end
