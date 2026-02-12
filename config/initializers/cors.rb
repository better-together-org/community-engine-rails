# frozen_string_literal: true

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('ALLOWED_ORIGINS', '*')

    resource "#{BetterTogether.route_scope_path}/api/*",
             headers: %w[Authorization],
             expose: %w[Authorization],
             methods: %i[get post put patch delete options head]
  end
end
