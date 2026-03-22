# frozen_string_literal: true

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Default to empty string (no origins allowed) when ALLOWED_ORIGINS is not set.
    # In production, set ALLOWED_ORIGINS to a comma-separated list of trusted origins.
    origins(*ENV.fetch('ALLOWED_ORIGINS', '').split(',').map(&:strip).reject(&:empty?))

    resource "#{BetterTogether.route_scope_path}/api/*",
             headers: %w[Authorization Content-Type Accept],
             expose: %w[Authorization],
             methods: %i[get post put patch delete options head],
             max_age: 7200
  end
end
