# frozen_string_literal: true

require 'nokogiri'
require 'uri'

module BetterTogether
  # Rewrites rendered markdown links so only external HTTP/S targets open in a new tab.
  class MarkdownLinkTargetRewriter
    EXTERNAL_REL_TOKENS = %w[noopener noreferrer].freeze
    NON_HTTP_PREFIXES = ['#', '/', 'mailto:', 'tel:'].freeze

    def initialize(html)
      @html = html
    end

    def call
      fragment.css('a[href]').each { |link| rewrite_link!(link) }
      fragment.to_html
    end

    private

    attr_reader :html

    def fragment
      @fragment ||= Nokogiri::HTML::DocumentFragment.parse(html)
    end

    def rewrite_link!(link)
      return make_external!(link) if external_http_link?(link['href'])

      link.remove_attribute('target')
      update_rel!(link, rel_tokens(link['rel']) - EXTERNAL_REL_TOKENS)
    end

    def make_external!(link)
      link['target'] = '_blank'
      update_rel!(link, rel_tokens(link['rel']) | EXTERNAL_REL_TOKENS)
    end

    def update_rel!(link, tokens)
      tokens.any? ? link['rel'] = tokens.join(' ') : link.remove_attribute('rel')
    end

    def external_http_link?(href)
      uri = parsed_link_uri(href)
      uri&.host.present? && %w[http https].include?(uri.scheme) && !platform_hosts.include?(normalized_host(uri.host))
    end

    def parsed_link_uri(href)
      return nil if href.blank? || NON_HTTP_PREFIXES.any? { |prefix| href.start_with?(prefix) }

      URI.parse(href.start_with?('//') ? "https:#{href}" : href)
    rescue URI::InvalidURIError
      nil
    end

    def platform_hosts
      @platform_hosts ||= begin
        hostnames = platform_hostnames
        hostnames << normalized_host(parsed_host(active_platform&.host_url))
        hostnames.compact.uniq
      end
    end

    def platform_hostnames
      return [] unless active_platform && BetterTogether::Platform.connection.data_source_exists?('better_together_platform_domains')

      active_platform.platform_domains.active.pluck(:hostname).map { |hostname| normalized_host(hostname) }
    end

    def active_platform
      @active_platform ||= Current.platform || BetterTogether::Platform.find_by(host: true)
    end

    def parsed_host(url)
      URI.parse(url.to_s).host
    rescue URI::InvalidURIError
      nil
    end

    def normalized_host(host)
      host.present? ? BetterTogether::PlatformDomain.normalize_hostname(host) : nil
    end

    def rel_tokens(value)
      value.to_s.split(/\s+/).reject(&:blank?)
    end
  end
end
