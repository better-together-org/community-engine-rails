# frozen_string_literal: true

module BetterTogether
  # Adds long-lived cache headers to fingerprinted files under /assets when the
  # response has none. The digest in the file name changes with the content, so
  # a year-long immutable lifetime is safe.
  class ImmutableAssetCache
    FINGERPRINTED = %r{\A/assets/.+-[0-9a-f]{8,}\.[a-z0-9]+\z}i
    CACHE_CONTROL = 'public, max-age=31536000, immutable'

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      if status == 200 && env['PATH_INFO'].to_s.match?(FINGERPRINTED) && !headers.key?('cache-control') &&
         !headers.key?('Cache-Control')
        headers['cache-control'] = CACHE_CONTROL
      end
      [status, headers, body]
    end
  end
end
