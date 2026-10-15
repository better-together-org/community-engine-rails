# frozen_string_literal: true

require 'sidekiq/api'

module BetterTogether
  # Regenerates XML sitemaps so newly published content is indexed.
  #
  # With no argument it sweeps every locally-hosted platform. With a platform id
  # it regenerates just that platform, which is what content-model `after_commit`
  # hooks enqueue (see BetterTogether::SitemapRefreshable).
  class SitemapRefreshJob < ApplicationJob
    queue_as :default

    class << self
      # Enqueue a refresh unless an equivalent job is already pending.
      # A pending full sweep (no id) suppresses everything; a pending scoped job
      # only suppresses another job for the same platform.
      def enqueue_unless_pending(platform_id = nil)
        return perform_later(*Array(platform_id)) unless pending?(platform_id)

        false
      end

      def pending?(platform_id = nil)
        enqueued?(platform_id) || running?(platform_id)
      end

      private

      def enqueued?(platform_id)
        Sidekiq::Queue.new(queue_name).any? { |job| matches?(job.item, platform_id) }
      rescue StandardError
        false
      end

      def running?(platform_id)
        Sidekiq::Workers.new.any? do |_process_id, _thread_id, work|
          matches?(work.respond_to?(:job) ? work.job : work, platform_id)
        end
      rescue StandardError
        false
      end

      def matches?(payload, platform_id)
        return false unless payload.is_a?(Hash)
        return false unless wrapped_job_class(payload) == name

        pending_args = job_arguments(payload)
        # A queued full sweep covers every platform.
        return true if pending_args.compact.empty?

        # Otherwise it only covers the specific platform it targets.
        platform_id.present? && pending_args.map(&:to_s).include?(platform_id.to_s)
      end

      def wrapped_job_class(payload)
        payload['wrapped'] || payload['class']
      end

      def job_arguments(payload)
        Array(payload.dig('args', 0, 'arguments') || payload['arguments'])
      end
    end

    def perform(platform_id = nil)
      if platform_id.present?
        platform = BetterTogether::Platform.internal.find_by(id: platform_id)
        return unless platform

        BetterTogether::Sitemaps::Generator.new(platform).call
      else
        BetterTogether::Platform.internal.find_each do |platform|
          BetterTogether::Sitemaps::Generator.new(platform).call
        rescue StandardError => e
          Rails.logger.error "Sitemap generation failed for platform #{platform.id}: #{e.message}"
        end
      end
    end
  end
end
