# frozen_string_literal: true

module BetterTogether
  # Defensively percent-encodes path strings before use in redirect URLs.
  #
  # Background:
  #   The catch-all locale-redirect route must encode non-ASCII and URI-invalid
  #   ASCII characters before passing the path to ActionDispatch::Routing::Redirect.
  #   Without encoding, paths that include UTF-8 characters (e.g. /fr/à-propos-de-nous)
  #   or literal brackets/spaces cause URI::InvalidURIError when ActionDispatch calls
  #   URI.parse on the redirect target.  These errors surfaced as 500s on Sentry before
  #   this fix was introduced.
  #
  # Two-pass strategy:
  #   1. Encode any non-ASCII bytes (code points > U+007F) byte-by-byte with %XX notation.
  #   2. Encode RFC-3986-unsafe ASCII delimiters that are technically in the 7-bit range
  #      but are not allowed unescaped in a URI path (brackets, spaces, backslash, etc.).
  #
  # References:
  #   RFC 3986 §2.2 (reserved characters)
  #   RFC 3986 §3.3 (path characters)
  module UrlSanitizer
    # Characters in the 7-bit ASCII range that are illegal or ambiguous in a URI path.
    # Sourced from RFC 3986 §3.3 and the URI::Parser regexp.
    URI_UNSAFE_ASCII = /[\[\]{}\s\\^`|<>]/.freeze

    # Encode all bytes of non-ASCII characters in +path+ using percent-notation,
    # then encode any remaining URI-unsafe ASCII delimiters.
    #
    # @param path [String] raw path segment (no leading slash required)
    # @return [String] percent-encoded path safe for use in a redirect URL
    def self.encode_path(path)
      path.to_s
          .gsub(/[^\x00-\x7F]/) { |c| c.bytes.map { |b| format('%%%02X', b) }.join }
          .gsub(URI_UNSAFE_ASCII) { |c| format('%%%02X', c.ord) }
    end
  end
end
