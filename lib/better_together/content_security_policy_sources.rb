# frozen_string_literal: true

require 'uri'

module BetterTogether
  # Computes CSP source lists, including an optional configured asset host origin.
  module ContentSecurityPolicySources
    module_function

    SCRIPT_SOURCES = [
      :self,
      :blob,
      'https://cdn.jsdelivr.net',
      'https://cdnjs.cloudflare.com',
      'https://unpkg.com',
      'https://ga.jspm.io'
    ].freeze

    STYLE_SOURCES = [
      :self,
      :unsafe_inline,
      'https://cdn.jsdelivr.net',
      'https://cdnjs.cloudflare.com',
      'https://unpkg.com'
    ].freeze

    IMG_SOURCES = [
      :self,
      :data,
      :blob,
      'https://*.tile.openstreetmap.org'
    ].freeze

    FONT_SOURCES = %i[self data].freeze

    def script_sources(raw_asset_host = ENV.fetch('ASSET_HOST', nil))
      with_asset_host(SCRIPT_SOURCES, raw_asset_host)
    end

    def style_sources(raw_asset_host = ENV.fetch('ASSET_HOST', nil))
      with_asset_host(STYLE_SOURCES, raw_asset_host)
    end

    def img_sources(raw_asset_host = ENV.fetch('ASSET_HOST', nil))
      with_asset_host(IMG_SOURCES, raw_asset_host)
    end

    def font_sources(raw_asset_host = ENV.fetch('ASSET_HOST', nil))
      with_asset_host(FONT_SOURCES, raw_asset_host)
    end

    def asset_host_source(raw_asset_host = ENV.fetch('ASSET_HOST', nil))
      asset_host = raw_asset_host.to_s.strip
      return nil if asset_host.empty?

      normalized = asset_host.include?('://') ? asset_host : "https://#{asset_host}"
      uri = URI.parse(normalized)
      host = uri.host
      return nil if host.nil? || host.empty?

      "#{uri.scheme || 'https'}://#{host}#{normalized_port(uri)}"
    rescue URI::InvalidURIError
      nil
    end

    def with_asset_host(sources, raw_asset_host = ENV.fetch('ASSET_HOST', nil))
      asset_host = asset_host_source(raw_asset_host)
      return sources.dup unless asset_host

      (sources + [asset_host]).uniq
    end

    def normalized_port(uri)
      return '' if uri.port.nil? || [80, 443].include?(uri.port)

      ":#{uri.port}"
    end
  end
end
