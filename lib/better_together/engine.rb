require 'better_together/column_definitions'
require 'better_together/migration_helpers'
require 'devise/jwt'

module BetterTogether
  class Engine < ::Rails::Engine
    engine_name 'better_together'
    isolate_namespace BetterTogether

    config.autoload_paths << File.expand_path("lib/better_together", __dir__)

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, :dir => 'spec/factories'
    end

    config.before_initialize do
      require_dependency 'friendly_id'
      require_dependency 'mobility'
      require_dependency 'friendly_id/mobility'
      require_dependency 'jsonapi-resources'
      require_dependency 'pundit'
      require_dependency 'rack/cors'
    end

    config.action_mailer.default_url_options = {
      host: ENV.fetch('APP_HOST', 'localhost:3000'),
      locale: I18n.locale
    }
  end
end
