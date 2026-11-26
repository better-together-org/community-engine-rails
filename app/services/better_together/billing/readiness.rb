# frozen_string_literal: true

module BetterTogether
  module Billing
    # What a steward still has to do before the platform can sell: billing configured, a payment
    # method switched on, and in-force purchase agreements for each kind of purchase.
    #
    # It is a checklist for people. Checkout does not rely on it: each purchase runs its own
    # AgreementGate, which fails closed on the same facts.
    class Readiness
      Check = Data.define(:key, :ok, :purpose, :detail)

      PURPOSES = %w[subscription one_time].freeze

      # A paid order is followed up by jobs on the billing queue (starting the subscription, renewals, reminders).
      # A queued job older than this means nothing is taking them.
      BACKLOG_AFTER = 5.minutes
      REDIS_ERRORS = [RedisClient::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError, Timeout::Error].freeze

      def self.call(platform) = new(platform).call

      def initialize(platform)
        @platform = platform
      end

      def call = Result.new(checks:)

      Result = Data.define(:checks) do
        def ready? = checks.all?(&:ok)
        def pending = checks.reject(&:ok)
      end

      private

      attr_reader :platform

      def checks
        [configured, method_enabled, worker, *PURPOSES.map { |purpose| agreements_for(purpose) }]
      end

      def configured = Check.new(key: :configured, ok: Billing.configurable?(platform), purpose: nil, detail: nil)

      def method_enabled
        Check.new(key: :method_enabled, ok: Configuration.processors_for(platform).any?, purpose: nil, detail: nil)
      end

      # Whether a background worker is taking jobs from the billing queue. Without one, a paid order never turns
      # into a subscription. Only a Sidekiq deployment can be checked; any other queue adapter counts as fine.
      def worker
        problem = worker_problem
        Check.new(key: :worker, ok: problem.nil?, purpose: nil, detail: Array(problem))
      end

      def worker_problem
        return unless ActiveJob::Base.queue_adapter_name.to_s == 'sidekiq'

        queue = ApplicationJob.new.queue_name.to_s
        return :no_worker unless Sidekiq::ProcessSet.new(false).any? { |process| Array(process['queues']).include?(queue) }

        :backlog if Sidekiq::Queue.new(queue).latency > BACKLOG_AFTER
      rescue *REDIS_ERRORS
        :unreachable
      end

      def agreements_for(purpose)
        gate = Checkout::AgreementGate.new(platform:, purpose:, signer: nil)
        Check.new(key: :agreements, ok: gate.ready?, purpose:, detail: gate.problems.map(&:code).uniq)
      end
    end
  end
end
