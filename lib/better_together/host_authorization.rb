# frozen_string_literal: true

module BetterTogether
  # Lets Rails host authorization follow the platform's active domains.
  #
  # A host app that restricts config.hosts (an allow-list) would otherwise need a config change and a
  # restart for every new platform domain. With this installed, a hostname is also allowed when it is
  # an active PlatformDomain. A host app with an empty config.hosts is not restricted, and stays that
  # way: the matcher is only added to an existing allow-list. Unknown hostnames are still refused by
  # Rails (403) and, further in, by PlatformContextMiddleware when fail-closed routing is on.
  module HostAuthorization
    HOSTS_ENV_KEYS = %w[APP_HOSTS ALLOWED_HOSTS].freeze

    class << self
      # The hostnames named in the environment. APP_HOSTS is the documented name; ALLOWED_HOSTS is read
      # as an alias because older docs used it. Both are comma separated.
      def env_hosts(env = ENV)
        HOSTS_ENV_KEYS.flat_map { |key| env.fetch(key, '').split(',') }.map(&:strip).compact_blank.uniq
      end

      # Called by Rails with the Host header value, which may carry a port.
      def allowed?(host)
        hostname = host.to_s.sub(/:\d+\z/, '')
        hostname.present? && ::BetterTogether::PlatformDomain.resolve(hostname).present?
      rescue ActiveRecord::ActiveRecordError
        false
      end

      def matcher
        @matcher ||= ->(host) { allowed?(host) }
      end

      # Adds the matcher to an allow-list that is already in force. Returns true when added.
      def install!(hosts) # rubocop:disable Naming/PredicateMethod
        return false if hosts.empty? || hosts.include?(matcher)

        hosts << matcher
        true
      end
    end
  end
end
