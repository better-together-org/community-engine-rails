# frozen_string_literal: true

require 'action_text/engine'
require 'active_storage/engine'
require 'activerecord-import'
require 'better_together/column_definitions'
require 'better_together/migration_helpers'
require 'bootstrap'
require 'dartsass-sprockets'
require 'devise/jwt'
require 'font-awesome-sass'
require 'importmap-rails'
require 'reform/rails'
require 'sprockets/railtie'
require 'stimulus-rails'
require 'turbo-rails'

module BetterTogether
  # Engine configuration for BetterTogether
  class Engine < ::Rails::Engine
    engine_name 'better_together'
    isolate_namespace BetterTogether

    config.autoload_paths << File.expand_path('lib/better_together', __dir__)

    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
      g.fixture_replacement :factory_bot, dir: 'spec/factories'
      g.test_framework :rspec
    end

    config.before_initialize do
      require_dependency 'friendly_id'
      require_dependency 'mobility'
      require_dependency 'friendly_id/mobility'
      require_dependency 'jsonapi-resources'
      require_dependency 'importmap-rails'
      require_dependency 'pundit'
      require_dependency 'rack/cors'
    end

    config.action_mailer.default_url_options = {
      host: ENV.fetch('APP_HOST', 'localhost:3000'),
      locale: I18n.locale
    }

    initializer 'better_together.importmap', before: 'importmap' do |app|
      app.config.importmap.paths << Engine.root.join('config/importmap.rb')

      # NOTE: something about cache; I did not look into it.
      # https://github.com/rails/importmap-rails#sweeping-the-cache-in-development-and-test
      app.config.importmap.cache_sweepers << root.join('app/assets/javascripts')
    end

    # NOTE: add engine manifest to precompile assets in production
    initializer 'better_together.assets' do |app|
      app.config.assets.precompile += %w[better_together_manifest]
      app.config.assets.paths << root.join('app', 'assets', 'images')
      app.config.assets.paths << root.join('app', 'javascript')
    end

    initializer 'better_together.turbo' do |app|
      app.config.action_view.form_with_generates_remote_forms = true
    end

    rake_tasks do
      load 'tasks/better_together_tasks.rake'

      Rake::Task['db:seed'].enhance do
        Rake::Task['better_together:load_seed'].invoke
      rescue RuntimeError
        Rake::Task['app:better_together:load_seed'].invoke
      end
    end
  end
end
