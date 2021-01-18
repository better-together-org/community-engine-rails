Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('ALLOWED_ORIGINS') { '*' }

    resource '/bt/api/*',
             headers: %w(Authorization),
             expose: %w(Authorization),
             methods: %i[get post put patch delete options head]
  end
end
