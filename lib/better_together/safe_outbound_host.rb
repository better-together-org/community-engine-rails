# frozen_string_literal: true

require 'faraday'
require 'resolv'
require 'ipaddr'

module BetterTogether
  # Resolves a hostname and refuses it when any address is private, loopback,
  # link-local or otherwise reserved. Used before outbound requests whose target a
  # tenant controls (OpenID Connect issuer discovery and the endpoints it names).
  # DNS can still change between this check and the connection (rebinding); the
  # check narrows the SSRF surface, it does not replace network egress rules.
  module SafeOutboundHost
    class UnsafeHost < StandardError; end

    module_function

    def assert_public!(host) # rubocop:disable Naming/PredicateMethod
      raise UnsafeHost, 'blank host' if host.blank?

      addresses = literal_address(host) || Resolv.getaddresses(host.to_s)
      raise UnsafeHost, 'host does not resolve' if addresses.empty?

      addresses.each do |address|
        raise UnsafeHost, 'host resolves to a non-public address' if private_address?(address)
      end
      true
    end

    def public_host?(host)
      assert_public!(host)
    rescue UnsafeHost
      false
    end

    def private_address?(address)
      ip = IPAddr.new(address.to_s)
      ip = ip.native if ip.ipv4_mapped?
      SafeFederationUrlValidator::PRIVATE_RANGES.any? { |range| range.include?(ip) }
    rescue IPAddr::InvalidAddressError
      true
    end

    def literal_address(host)
      IPAddr.new(host.to_s)
      [host.to_s]
    rescue IPAddr::InvalidAddressError
      nil
    end

    # Faraday middleware: checks every request URL (discovery, JWKS, token endpoints).
    class Guard < Faraday::Middleware
      def call(env)
        SafeOutboundHost.assert_public!(env.url.host)
        @app.call(env)
      end
    end
  end
end
