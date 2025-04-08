# frozen_string_literal: true

require 'action_cable/engine'
require 'action_text/engine'
require 'active_storage/engine'
require 'active_storage_svg_sanitizer'
require 'active_storage_validations'
require 'activerecord-import'
require 'activerecord-postgis-adapter'
require 'better_together/column_definitions'
require 'better_together/migration_helpers'
require 'bootstrap'
require 'dartsass-sprockets'
require 'devise'
require 'devise-i18n'
require 'devise/jwt'
require 'elasticsearch/model'
require 'elasticsearch/rails'
require 'font-awesome-sass'
require 'geocoder'
require 'groupdate'
require 'humanize_boolean'
require 'i18n-timezones'
require 'importmap-rails'
require 'noticed'
require 'premailer/rails'
require 'reform/rails'
require 'ruby/openai'
require 'simple_calendar'
require 'sprockets/railtie'
require 'stimulus-rails'
require 'translate_enum'
require 'turbo-rails'
require 'rack-mini-profiler'
require 'memory_profiler'
require 'stackprof'

module BetterTogether
  # Engine configuration for BetterTogether
  class Engine < ::Rails::Engine
    engine_name 'better_together'
    isolate_namespace BetterTogether

    config.autoload_paths += Dir["#{config.root}/lib/better_together/**/"]

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

    default_url_options = {
      host: ENV.fetch('APP_HOST', 'localhost:3000'),
      protocol: ENV.fetch('APP_PROTOCOL', 'http')
    }

    routes.default_url_options =
      config.action_mailer.default_url_options =
        config.default_url_options =
          default_url_options

    config.time_zone = ENV.fetch('APP_TIME_ZONE', 'Newfoundland')

    initializer 'better_together.configure_active_job' do |app|
      app.config.active_job.queue_adapter = :sidekiq
    end

    initializer 'better_together.action_mailer' do |app|
      if Rails.env.development?
        app.config.action_mailer.show_previews = true
        app.config.action_mailer.preview_paths = app.config.action_mailer.preview_paths +
                                                 [BetterTogether::Engine.root.join('spec/mailers/previews')]
      else
        app.config.action_mailer.show_previews = false
      end
    end

    # Add engine manifest to precompile assets in production
    initializer 'better_together.assets' do |app|
      # Ensure we are not modifying frozen arrays
      app.config.assets.precompile += %w[better_together_manifest.js]
      app.config.assets.paths = [root.join('app', 'assets', 'images'),
                                 root.join('app', 'javascript'),
                                 root.join('vendor', 'javascript'),
                                 root.join('vendor', 'stylesheets'),
                                 root.join('vendor', 'javascripts')] + app.config.assets.paths.to_a
    end

    initializer 'better_together.i18n' do |app|
      app.config.i18n.available_locales = ENV.fetch('APP_AVAILABLE_LOCALES', 'en,fr,es').split(',').map(&:to_sym)
      app.config.i18n.default_locale = ENV.fetch('APP_DEFAULT_LOCALE', :en).to_sym
      app.config.i18n.fallbacks = ENV.fetch('APP_FALLBACK_LOCALES', 'en,fr,es').split(',').map(&:to_sym)
    end

    initializer 'better_together.importmap', before: 'importmap' do |app|
      # Ensure we are not modifying frozen arrays
      app.config.importmap.paths = [Engine.root.join('config/importmap.rb')] + app.config.importmap.paths.to_a
      app.config.importmap.cache_sweepers = [root.join('app/assets/javascripts'),
                                             root.join('app/javascript')] + app.config.importmap.cache_sweepers.to_a
    end

    initializer 'better_together.importmap.pins', after: 'importmap' do |app|
      if app.respond_to?(:importmap) && app.importmap
        app.importmap.pin 'better_together/application', to: 'better_together/application.js'
        # If you have multiple controllers or additional JavaScript files, pin them accordingly:
        app.importmap.pin_all_from 'better_together/controllers', under: 'better_together/controllers'
        # Add other specific pins as necessary
      else
        Rails.logger.warn "Importmap not initialized. Unable to pin 'better_together/application'."
      end
    end

    # Add custom logging
    initializer 'better_together.logging', before: :initialize_logger do |app|
      app.config.log_tags = %i[request_id remote_ip]
    end

    # Exclude postgis tables from database dumper
    initializer 'better_together.spatial_tables' do
      ::ActiveRecord::SchemaDumper.ignore_tables = %w[spatial_ref_sys] + ::ActiveRecord::SchemaDumper.ignore_tables
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
