# frozen_string_literal: true

module BetterTogether
  # Wraps Sidekiq::Web. Sidekiq ignores a locale query param and reads session[:locale] instead, so a
  # `?locale=` param is mapped to a locale Sidekiq ships (exact, then case and separator insensitive,
  # then the base language, then en) and stored there before Sidekiq renders.
  class SidekiqWebLocale
    PARAM = 'locale'
    FALLBACK = 'en'

    def self.available_locales
      @available_locales ||= Sidekiq::Web.locales.flat_map { |path| Dir[File.join(path, '*.yml')] }
                                         .map { |file| File.basename(file, '.yml') }.uniq.sort
    end

    def self.match(requested)
      return nil if requested.blank?

      wanted = requested.to_s.strip.tr('_', '-')
      return nil unless wanted.match?(/\A[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*\z/)

      exact = available_locales.find { |locale| locale.casecmp?(wanted) }
      exact || available_locales.find { |locale| locale.casecmp?(wanted.split('-').first) } || FALLBACK
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      locale = self.class.match(requested_locale(env))
      session = env['rack.session']
      session[:locale] = locale if locale && session
      @app.call(env)
    end

    private

    def requested_locale(env)
      Rack::Request.new(env).GET[PARAM]
    rescue Rack::QueryParser::ParameterTypeError, Rack::QueryParser::InvalidParameterError
      nil
    end
  end
end
