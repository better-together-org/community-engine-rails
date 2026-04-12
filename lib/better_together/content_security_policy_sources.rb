# frozen_string_literal: true

require 'uri'

module BetterTogether
  # Computes CSP source lists, including an optional configured asset host origin.
  # rubocop:disable Metrics/ModuleLength
  module ContentSecurityPolicySources
    module_function

    ORIGIN_SPLIT_PATTERN = /[\s,]+/

    SCRIPT_SOURCES = [
      :self,
      :blob,
      'https://cdn.jsdelivr.net',
      'https://cdnjs.cloudflare.com',
      'https://unpkg.com',
      'https://ga.jspm.io'
    ].freeze

    CONNECT_SOURCES = %i[self wss].freeze

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
      'https://unpkg.com',
      'https://*.tile.openstreetmap.org'
    ].freeze

    FONT_SOURCES = %i[self data].freeze

    def script_sources(raw_asset_host = ENV.fetch('ASSET_HOST', nil), raw_script_src = ENV.fetch('CSP_SCRIPT_SRC', nil))
      env_sources = parse_origin_list(raw_script_src)
      dynamic_sources = dynamic_platform_sources(:csp_script_src)

      with_asset_host(SCRIPT_SOURCES + env_sources + dynamic_sources, raw_asset_host)
    end

    def style_sources(raw_asset_host = ENV.fetch('ASSET_HOST', nil))
      with_asset_host(STYLE_SOURCES, raw_asset_host)
    end

    def img_sources(raw_asset_host = ENV.fetch('ASSET_HOST', nil), raw_img_src = ENV.fetch('CSP_IMG_SRC', nil))
      env_sources = parse_origin_list(raw_img_src)
      dynamic_sources = dynamic_platform_sources(:csp_img_src)

      with_asset_host(IMG_SOURCES + env_sources + dynamic_sources, raw_asset_host)
    end

    def font_sources(raw_asset_host = ENV.fetch('ASSET_HOST', nil))
      with_asset_host(FONT_SOURCES, raw_asset_host)
    end

    def connect_sources(raw_connect_src = ENV.fetch('CSP_CONNECT_SRC', nil))
      env_sources = parse_origin_list(raw_connect_src)
      dynamic_sources = dynamic_platform_sources(:csp_connect_src)

      CONNECT_SOURCES + env_sources + dynamic_sources
    end

    def frame_sources(raw_frame_src = ENV.fetch('CSP_FRAME_SRC', nil))
      [:self] + parse_origin_list(raw_frame_src) + dynamic_platform_sources(:csp_frame_src)
    end

    def frame_ancestor_sources(raw_frame_ancestors = ENV.fetch('CSP_FRAME_ANCESTORS', nil))
      env_sources = parse_origin_list(raw_frame_ancestors)

      [lambda {
        BetterTogether::ContentSecurityPolicySources.merged_sources(
          env_sources,
          BetterTogether::ContentSecurityPolicySources.platform_sources_for_context(self, :csp_frame_ancestors)
        ).presence || [:none]
      }]
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

    def parse_origin_list(raw_value)
      origin_tokens(raw_value).filter_map { |origin| normalize_origin(origin) }.uniq
    end

    def invalid_origins(raw_value)
      origin_tokens(raw_value).reject { |origin| normalize_origin(origin) }.uniq
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def normalize_origin(origin)
      value = origin.to_s.strip
      return nil if value.empty?

      normalized = value.include?('://') ? value : "https://#{value}"
      uri = URI.parse(normalized)
      return nil unless uri.is_a?(URI::HTTP) && uri.host.present?
      return nil unless uri.scheme == 'https'
      return nil if uri.userinfo.present? || uri.query.present? || uri.fragment.present?
      return nil unless uri.path.blank? || uri.path == '/'

      "#{uri.scheme}://#{uri.host}#{normalized_port(uri)}"
    rescue URI::InvalidURIError
      nil
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def origin_for_url(value)
      url = value.to_s.strip
      return nil if url.empty?

      uri = URI.parse(url)
      return nil unless uri.is_a?(URI::HTTP) && uri.host.present?
      return nil unless uri.scheme == 'https'
      return nil if uri.userinfo.present?

      "#{uri.scheme}://#{uri.host}#{normalized_port(uri)}"
    rescue URI::InvalidURIError
      nil
    end

    def origin_tokens(raw_value)
      Array(raw_value)
        .flat_map { |value| value.to_s.split(ORIGIN_SPLIT_PATTERN) }
        .map(&:strip)
        .reject(&:empty?)
    end

    def platform_sources(platform, setting_key)
      return [] unless platform.respond_to?(setting_key)

      Array(platform.public_send(setting_key)).filter_map { |value| normalize_origin(value) }.uniq
    end

    def dynamic_platform_sources(setting_key)
      [-> { BetterTogether::ContentSecurityPolicySources.platform_sources_for_context(self, setting_key) }]
    end

    def merged_sources(*source_groups)
      source_groups.flatten.compact.uniq
    end

    def platform_sources_for_context(context, setting_key)
      host = if context.respond_to?(:request)
               context.request&.host
             elsif context.respond_to?(:host)
               context.host
             end
      platform = platform_for_host(host)
      platform_sources(platform, setting_key)
    end

    def platform_for_host(host)
      return BetterTogether::Platform.find_by(host: true) if host.blank?

      resolved_domain = BetterTogether::PlatformDomain.resolve(host)
      resolved_platform = BetterTogether::Platform.find_by(id: resolved_domain&.platform_id)

      resolved_platform || BetterTogether::Platform.find_by(host: true)
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
