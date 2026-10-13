# frozen_string_literal: true

require 'uri'

module BetterTogether
  module Mcp
    # Hostnames MCP accepts in the Origin header (or, when there is none, the referer or request host).
    #
    # Derived from the platform's configured domains so the list follows them: active PlatformDomain
    # hostnames plus the host of each internal (non-federated) Platform#host_url. PlatformDomain and
    # Platform changes clear the cached list; the short TTL bounds staleness on per-process cache stores.
    # MCP_ALLOWED_ORIGINS (comma-separated hostnames) adds hostnames for clients outside the platform, and
    # development also allows the local hosts. An empty list allows nothing (fail closed).
    module AllowedOrigins
      CACHE_KEY = 'bt:mcp:allowed_origin_hostnames'
      CACHE_TTL = 1.minute
      DEVELOPMENT_HOSTS = %w[localhost 127.0.0.1 0.0.0.0].freeze

      class << self
        def allowed?(hostname)
          normalized = normalize(hostname)
          normalized.present? && hostnames.include?(normalized)
        end

        def hostnames
          (extra_hostnames + platform_hostnames).uniq
        end

        def reset_cache!
          Rails.cache.delete(CACHE_KEY)
        end

        private

        def extra_hostnames
          configured = ENV.fetch('MCP_ALLOWED_ORIGINS', '').split(',').filter_map { |name| normalize(name).presence }
          Rails.env.development? ? configured + DEVELOPMENT_HOSTS : configured
        end

        def platform_hostnames
          Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { load_platform_hostnames }
        rescue ActiveRecord::ActiveRecordError => e
          Rails.logger.warn("[BetterTogether::Mcp] allowed origins unavailable: #{e.class}: #{e.message}")
          []
        end

        def load_platform_hostnames
          domains = BetterTogether::PlatformDomain.active.pluck(:hostname)
          urls = BetterTogether::Platform.internal.pluck(:url).filter_map { |url| url_host(url) }
          (domains + urls).filter_map { |name| normalize(name).presence }.uniq
        end

        def url_host(url)
          URI.parse(url.to_s).host
        rescue URI::InvalidURIError
          nil
        end

        def normalize(hostname)
          BetterTogether::PlatformDomain.normalize_hostname(hostname)
        end
      end
    end
  end
end
