# frozen_string_literal: true

module BetterTogether
  # In-memory registry for subsystem adapters/providers.
  # Each subsystem can register multiple named adapters and dispatch to all of them.
  class AdapterRegistry
    # Raised after dispatch fan-out completes when one or more adapters fail.
    class DispatchError < StandardError
      attr_reader :group, :failures

      def initialize(group:, failures:)
        @group = group
        @failures = failures
        super(build_message(group, failures))
      end

      private

      def build_message(group, failures)
        failure_summary = failures.map do |failure|
          adapter_name = failure[:name] || 'anonymous'
          "#{adapter_name} (#{failure[:error].class}: #{failure[:error].message})"
        end.join(', ')

        "Adapter dispatch failed for #{group}: #{failure_summary}"
      end
    end

    def initialize
      @entries = Hash.new { |hash, key| hash[key] = [] }
    end

    def register(group, name = nil, adapter = nil, &block)
      callable = adapter || block
      raise ArgumentError, 'adapter must respond to #call' unless callable.respond_to?(:call)

      key = normalize_group(group)
      @entries[key] = @entries[key].reject { |entry| entry[:name] == name } if name.present?
      @entries[key] << { name:, adapter: callable }
    end

    def adapters_for(group)
      @entries[normalize_group(group)].dup
    end

    def adapter_for(group, name = nil)
      entries = adapters_for(group)
      return entries.first if name.nil?

      entries.find { |entry| entry[:name]&.to_sym == name.to_sym }
    end

    def clear!(group = nil)
      return @entries.clear if group.nil?

      @entries.delete(normalize_group(group))
    end

    def dispatch(group, *, **)
      normalized_group = normalize_group(group)
      failures = []
      results = adapters_for(normalized_group).map do |entry|
        entry.fetch(:adapter).call(*, **)
      rescue StandardError => e
        log_dispatch_failure(normalized_group, entry, e)
        failures << { name: entry[:name], error: e }
        nil
      end

      raise DispatchError.new(group: normalized_group, failures:) if failures.any?

      results
    end

    def groups
      @entries.keys
    end

    private

    def normalize_group(group)
      group.to_sym
    end

    def log_dispatch_failure(group, entry, error)
      return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

      adapter_name = entry[:name] || 'anonymous'
      Rails.logger.error("[AdapterDispatchFailure] group=#{group} adapter=#{adapter_name} #{error.class}: #{error.message}")
    end
  end
end
