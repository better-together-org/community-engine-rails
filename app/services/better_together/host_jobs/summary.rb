# frozen_string_literal: true

module BetterTogether
  module HostJobs
    # Counts for the background jobs summary panel, read from the Sidekiq API and cached briefly so a
    # page left open does not hammer Redis. When Redis cannot be reached it returns an unavailable
    # snapshot instead of raising, and that snapshot is not cached.
    class Summary
      CACHE_KEY = 'better_together/host_jobs/summary'
      CACHE_TTL = 10.seconds
      DEFAULT_STALLED_AFTER = 10.minutes
      REDIS_ERRORS = [RedisClient::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError,
                      Timeout::Error].freeze

      QueueRow = Data.define(:name, :size, :latency)
      Snapshot = Data.define(:available, :failed, :retrying, :dead, :scheduled, :enqueued, :queues,
                             :longest_latency, :busy, :stalled, :processes, :stalled_after, :fetched_at) do
        def available? = available
        def no_processes? = available && processes.zero?

        # Counts the panel watches: a rise in a trouble count, or workers dropping to zero, is announced.
        def watched_counts
          { failed:, retrying:, dead:, stalled:, processes: }
        end
      end

      def self.stalled_after
        minutes = ENV.fetch('HOST_JOBS_STALLED_AFTER_MINUTES', nil).to_i
        minutes.positive? ? minutes.minutes : DEFAULT_STALLED_AFTER
      end

      def self.call(cache: Rails.cache, stalled_after: self.stalled_after, now: Time.current)
        cached = cache.read(CACHE_KEY)
        return cached if cached

        snapshot = new(stalled_after:, now:).snapshot
        cache.write(CACHE_KEY, snapshot, expires_in: CACHE_TTL) if snapshot.available?
        snapshot
      end

      def initialize(stalled_after: self.class.stalled_after, now: Time.current)
        @stalled_after = stalled_after
        @now = now
      end

      def snapshot
        stats = Sidekiq::Stats.new
        queues = queue_rows
        work = work_rows
        build(stats, queues, work)
      rescue *REDIS_ERRORS => e
        Rails.logger.warn("[HostJobs::Summary] Sidekiq unavailable: #{e.class}")
        unavailable
      end

      private

      attr_reader :stalled_after, :now

      def build(stats, queues, work)
        Snapshot.new(available: true, **counts(stats), enqueued: queues.sum(&:size), queues:,
                     longest_latency: queues.map(&:latency).max.to_f, busy: work.size,
                     stalled: work.count { |run_at| run_at <= now - stalled_after },
                     processes: Sidekiq::ProcessSet.new(false).size, stalled_after:, fetched_at: now)
      end

      def counts(stats)
        { failed: stats.failed.to_i, retrying: stats.retry_size.to_i, dead: stats.dead_size.to_i,
          scheduled: stats.scheduled_size.to_i }
      end

      # Stats#queue_summaries is Sidekiq 8 only; Queue.all works on 7.3 (Rails 7.2 lane) and 8.
      def queue_rows
        Sidekiq::Queue.all.map { |queue| QueueRow.new(name: queue.name, size: queue.size.to_i, latency: queue.latency.to_f) }
                      .sort_by { |row| [-row.size, row.name] }
      end

      def work_rows
        Sidekiq::WorkSet.new.map { |_process, _thread, work| work.run_at }
      end

      def unavailable
        Snapshot.new(available: false, failed: 0, retrying: 0, dead: 0, scheduled: 0, enqueued: 0, queues: [],
                     longest_latency: 0.0, busy: 0, stalled: 0, processes: 0, stalled_after:, fetched_at: now)
      end
    end
  end
end
