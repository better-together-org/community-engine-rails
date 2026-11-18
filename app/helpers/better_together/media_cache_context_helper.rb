# frozen_string_literal: true

module BetterTogether
  # Cache-key part for fragments that hold media URLs.
  module MediaCacheContextHelper
    # The origin media URLs are built against. Proxy URLs are absolute, so a fragment that holds one is only right
    # for the host it was rendered on; keying on the origin stops one host's fragment serving another's pages.
    def media_url_cache_context
      request&.base_url if respond_to?(:request)
    end
  end
end
