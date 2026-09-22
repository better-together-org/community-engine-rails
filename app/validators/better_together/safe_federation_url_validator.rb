# frozen_string_literal: true

module BetterTogether
  # Validates that a URL is safe for outbound federation requests.
  #
  # Rejects URLs targeting private/reserved IP ranges to prevent SSRF attacks
  # where a malicious platform operator could point federation pull services at
  # internal infrastructure (metadata endpoints, databases, local services).
  #
  # Allows hostnames that resolve to public IPs — DNS rebinding is a separate
  # concern addressed at the HTTP client layer.
  class SafeFederationUrlValidator < ActiveModel::EachValidator
    # RFC 1918 private ranges + loopback + link-local + reserved ranges
    PRIVATE_RANGES = [
      IPAddr.new('0.0.0.0/8'),          # "This" network
      IPAddr.new('10.0.0.0/8'),         # Private class A
      IPAddr.new('100.64.0.0/10'),      # Shared address space (RFC 6598 - CGN)
      IPAddr.new('127.0.0.0/8'),        # Loopback
      IPAddr.new('169.254.0.0/16'),     # Link-local (AWS/GCP metadata: 169.254.169.254)
      IPAddr.new('172.16.0.0/12'),      # Private class B
      IPAddr.new('192.0.0.0/24'),       # IETF protocol assignments
      IPAddr.new('192.168.0.0/16'),     # Private class C
      IPAddr.new('198.18.0.0/15'),      # Benchmarking
      IPAddr.new('198.51.100.0/24'),    # TEST-NET-2 (documentation)
      IPAddr.new('203.0.113.0/24'),     # TEST-NET-3 (documentation)
      IPAddr.new('224.0.0.0/4'),        # Multicast
      IPAddr.new('240.0.0.0/4'),        # Reserved
      IPAddr.new('::1/128'),            # IPv6 loopback
      IPAddr.new('fc00::/7'),           # IPv6 unique local
      IPAddr.new('fe80::/10'),          # IPv6 link-local
      IPAddr.new('ff00::/8')            # IPv6 multicast
    ].freeze

    def validate_each(record, attribute, value)
      return if value.blank?

      uri = parse_uri(value)
      return record.errors.add(attribute, :invalid_url, message: url_error) unless uri

      check_scheme(record, attribute, uri)
      check_host(record, attribute, uri)
      check_credentials(record, attribute, uri)
    end

    private

    def parse_uri(value)
      URI.parse(value)
    rescue URI::InvalidURIError
      nil
    end

    def check_scheme(record, attribute, uri)
      return if %w[https http].include?(uri.scheme)

      record.errors.add(attribute, :insecure_scheme,
                        message: I18n.t('better_together.validators.safe_federation_url.insecure_scheme'))
    end

    def check_host(record, attribute, uri)
      return if uri.host.blank?

      ip = IPAddr.new(uri.host)
      if PRIVATE_RANGES.any? { |range| range.include?(ip) }
        record.errors.add(attribute, :private_ip,
                          message: I18n.t('better_together.validators.safe_federation_url.private_ip'))
      end
    rescue IPAddr::InvalidAddressError
      # Hostname (not an IP literal) — allow it; DNS resolution happens at request time
    end

    def check_credentials(record, attribute, uri)
      return if uri.userinfo.blank?

      record.errors.add(attribute, :credentials_in_url,
                        message: I18n.t('better_together.validators.safe_federation_url.credentials_in_url'))
    end

    def url_error
      I18n.t('better_together.validators.safe_federation_url.invalid_url')
    end
  end
end
