# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Helper module for handling UTF-8 URLs in metrics models
    module Utf8UrlHandler
      extend ActiveSupport::Concern

      private

      # Parse a URL that may contain UTF-8 characters
      # @param url [String] The URL to parse
      # @return [URI::Generic, nil] Parsed URI or nil if invalid
      def safe_parse_uri(url) # rubocop:todo Metrics/MethodLength
        return if url.blank?

        # First try with the URL as-is
        begin
          URI.parse(url)
        rescue URI::InvalidURIError
          # If that fails, try encoding it
          encoded_url = encode_utf8_url(url)
          begin
            URI.parse(encoded_url)
          rescue URI::InvalidURIError
            nil
          end
        end
      end

      # Encode UTF-8 characters in a URL while preserving the structure
      # @param url [String] The URL to encode
      # @return [String] URL-encoded string
      def encode_utf8_url(url) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        return url if url.blank?

        # Split URL into components to avoid encoding the protocol/scheme
        if url.match(%r{\A([a-z]+://)}i)
          scheme_and_authority, path_and_query = url.split('/', 3)
          if path_and_query.present?
            encoded_path = path_and_query.split('?').map do |part|
              encode_utf8_component(part)
            end.join('?')
            "#{scheme_and_authority}/#{encoded_path}"
          else
            # Encode just the host part if no path
            parts = url.split('//')
            if parts.length > 1
              protocol = parts[0]
              host_and_rest = parts[1]
              "#{protocol}//#{encode_host_component(host_and_rest)}"
            else
              url
            end
          end
        else
          # No protocol, encode the whole thing
          encode_utf8_component(url)
        end
      end

      # Encode UTF-8 characters in a URL component
      # @param component [String] The URL component to encode
      # @return [String] Encoded component
      def encode_utf8_component(component)
        return component if component.blank?

        # Only encode non-ASCII characters
        component.gsub(/[^\x00-\x7F]/) { |char| CGI.escape(char) }
      end

      # Encode UTF-8 characters in a host component (for IDN support)
      # @param host_component [String] The host component to encode
      # @return [String] Encoded host component
      def encode_host_component(host_component) # rubocop:todo Metrics/MethodLength, Metrics/PerceivedComplexity
        return host_component if host_component.blank?

        # For international domain names, we need special handling
        # Split by '/' to separate host from path
        parts = host_component.split('/', 2)
        host = parts[0]
        path = parts[1]

        # Convert international domain to punycode if needed
        encoded_host = begin
          # Try to convert to ASCII using Punycode for IDN support
          if host.match?(/[^\x00-\x7F]/)
            # For Ruby's built-in IDN support, we'll encode each part
            host_parts = host.split('.')
            encoded_parts = host_parts.map do |part|
              if part.match?(/[^\x00-\x7F]/)
                # Simple percent encoding for now
                encode_utf8_component(part)
              else
                part
              end
            end
            encoded_parts.join('.')
          else
            host
          end
        rescue StandardError
          # Fallback to percent encoding
          encode_utf8_component(host)
        end

        if path
          "#{encoded_host}/#{encode_utf8_component(path)}"
        else
          encoded_host
        end
      end

      # Validate if a URL is structurally valid for our purposes
      # @param url [String] The URL to validate
      # @return [Boolean] Whether the URL is valid
      def valid_utf8_url?(url)
        return false if url.blank?

        uri = safe_parse_uri(url)
        return false unless uri

        # Check if it has a valid scheme
        return false unless uri.scheme.present?

        # For our metrics, we accept http, https, tel, mailto
        allowed_schemes = %w[http https tel mailto]
        allowed_schemes.include?(uri.scheme.downcase)
      end
    end
  end
end
