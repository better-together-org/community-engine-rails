# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Turn false under Spring and add config.action_view.cache_template_loading = true.
  config.cache_classes = true

  # Eager loading loads your whole application. When running a single test locally,
  # this probably isn't necessary. It's a good idea to do in a continuous integration
  # system, or in some way before deploying your code.
  config.eager_load = ENV['CI'].present?

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }

  # Host authorization is on, as in production (config/initializers/hosts.rb reads APP_HOSTS there), so a
  # multi-domain feature cannot silently depend on every Host header being accepted. The allow-list covers
  # loopback and the name suffixes the specs and browser use; keep it in step with CAPYBARA_HOST_SUFFIXES in
  # spec/support/capybara.rb. Rails' '.suffix' shorthand matches only one label ('a.test', not 'a.b.test'),
  # so the suffixes are regexes that accept any depth, with an optional port.
  config.hosts = [
    IPAddr.new('0.0.0.0/0'), IPAddr.new('::/0'),
    /\A([a-z0-9-]+\.)*(localhost|test|example|example\.com)(:\d+)?\z/i
  ]

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Raise exceptions instead of rendering exception templates.
  # Use :none instead of boolean false to avoid deprecation in Rails 7.1
  config.action_dispatch.show_exceptions = :none

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Cap the test log: one rotated file, 100 MB each (an uncapped log reached 2.5 GB).
  # TaggedLogging keeps the `tagged` API that app code and specs call on Rails.logger.
  # TaggedLogging.logger only exists in Rails 8.0+, so wrap the logger for the 7.2 lane.
  config.logger = ActiveSupport::TaggedLogging.new(
    ActiveSupport::Logger.new(Rails.root.join('log/test.log'), 1, 100.megabytes)
  )

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Disable Rack::Attack throttling in tests to prevent false 503 errors
  config.middleware.delete Rack::Attack

  # Disable BetterErrors in test environment to prevent marshal errors with parallel_rspec
  # BetterErrors attaches Binding objects to exceptions which cannot be marshaled when
  # parallel_rspec tries to send results between workers, causing "no _dump_data is defined for class Binding" errors
  config.middleware.delete BetterErrors::Middleware if defined?(BetterErrors::Middleware)

  # Local and worktree test runs need stable encryption keys even when
  # credentials are not available inside ephemeral containers.
  config.active_record.encryption.primary_key = ENV.fetch(
    'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY',
    '4f7f0d8d0e2b7c8f9a1b2c3d4e5f60714f7f0d8d0e2b7c8f9a1b2c3d4e5f6071'
  )
  config.active_record.encryption.deterministic_key = ENV.fetch(
    'ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY',
    '6a8b0c1d2e3f40516a8b0c1d2e3f40516a8b0c1d2e3f40516a8b0c1d2e3f4051'
  )
  config.active_record.encryption.key_derivation_salt = ENV.fetch(
    'ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT',
    '8c9d0e1f2a3b4c5d8c9d0e1f2a3b4c5d8c9d0e1f2a3b4c5d8c9d0e1f2a3b4c5d'
  )
  config.active_record.encryption.support_unencrypted_data = true
  config.active_record.encryption.extend_queries = true
end
