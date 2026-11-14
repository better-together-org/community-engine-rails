# frozen_string_literal: true

module BetterTogether
  # Answers requests that match an active Redirect for the current platform.
  # Runs after PlatformContextMiddleware and before routing, so redirects win
  # over the pages catch-all and work for paths outside the locale scope
  # (legacy `.html` and PDF URLs).
  class RedirectMiddleware
    SKIPPED_PREFIXES = %w[/assets/ /packs/ /rails/ /cable /up /sidekiq].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      return @app.call(env) unless candidate?(request)

      result = Redirects::Resolver.call(platform_id: ::Current.platform&.id, path: request.path)
      return @app.call(env) unless result

      record_hit(result.id)
      respond(request, result)
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("[RedirectMiddleware] #{e.class}: #{e.message}")
      @app.call(env)
    end

    private

    def candidate?(request)
      (request.get? || request.head?) && SKIPPED_PREFIXES.none? { |prefix| request.path.start_with?(prefix) }
    end

    def respond(request, result)
      return [410, { 'Content-Type' => 'text/plain; charset=utf-8', 'Cache-Control' => 'public, max-age=300' }, ['Gone']] if result.status == 410

      headers = { 'Location' => location_for(request, result), 'Content-Type' => 'text/plain; charset=utf-8',
                  'Cache-Control' => 'public, max-age=300' }
      [result.status, headers, ['Redirecting']]
    end

    def location_for(request, result)
      target = result.to_path
      target = "#{request.base_url}#{target}" unless target.match?(%r{\Ahttps?://}i)
      query = request.query_string
      return target if !result.preserve_query || query.blank? || target.include?('?')

      "#{target}?#{query}"
    end

    def record_hit(id)
      Redirect.where(id:).update_all(['hit_count = hit_count + 1, last_hit_at = ?', Time.current]) # rubocop:disable Rails/SkipsModelValidations
    rescue ActiveRecord::ActiveRecordError
      nil
    end
  end
end
