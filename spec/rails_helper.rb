# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('dummy/config/environment', __dir__)
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'
require 'rails-controller-testing'

ActiveJob::Base.queue_adapter = :test

# Configure cache with worker-specific namespace for parallel test isolation
if ENV['TEST_ENV_NUMBER']
  Rails.cache = ActiveSupport::Cache::MemoryStore.new(namespace: "test_worker_#{ENV['TEST_ENV_NUMBER']}")
end

Dir[BetterTogether::Engine.root.join('spec/support/**/*.rb')].each { |f| require f }
Dir[BetterTogether::Engine.root.join('spec/factories/**/*.rb')].each { |f| require f }
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migrator.migrations_paths = 'db/migrate'
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  exit 1
end

# Essential tables that should be preserved across tests
ESSENTIAL_TABLES = %w[
  better_together_communities
  better_together_platforms
  better_together_roles
  better_together_resource_permissions
  better_together_role_resource_permissions
  better_together_navigation_areas
  better_together_navigation_items
  better_together_categories
  better_together_wizards
  better_together_wizard_step_definitions
  better_together_agreements
  mobility_string_translations
  mobility_text_translations
  action_text_rich_texts
  active_storage_blobs
  active_storage_attachments
  active_storage_variant_records
].freeze

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include Devise::Test::IntegrationHelpers, type: :request

  # Enable assigns method in request specs (requires rails-controller-testing gem)
  config.include Rails::Controller::Testing::TestProcess, type: :request
  config.include Rails::Controller::Testing::TemplateAssertions, type: :request
  config.include Rails::Controller::Testing::Integration, type: :request

  config.include Warden::Test::Helpers
  config.after { Warden.test_reset! }

  # Configure OmniAuth for test mode
  config.before(:suite) do
    OmniAuth.config.test_mode = true
  end

  config.after do
    OmniAuth.config.mock_auth[:github] = nil
  end

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [Rails.root.join('spec/fixtures')]

  # Use DatabaseCleaner, not transactional fixtures, to support JS/feature specs
  config.use_transactional_fixtures = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  config.include RequestSpecHelper, type: :request
  # config.include RequestSpecHelper, type: :controller
  config.include BetterTogether::CapybaraFeatureHelpers, type: :feature

  config.before(:suite) do
    DatabaseCleaner.allow_remote_database_url = true if ENV['ALLOW_REMOTE_DB_URL']

    # Pre-clear FK-dependent tables to avoid violations when referential integrity cannot be disabled
    begin
      BetterTogether::RoleResourcePermission.delete_all
      BetterTogether::NavigationItem.where.not(parent_id: nil).delete_all
      BetterTogether::NavigationItem.where(parent_id: nil).delete_all
    rescue StandardError => e
      Rails.logger.debug "Pre-clean step skipped or failed: #{e.message}"
    end

    # Full clean to start fresh using deletions to avoid deadlocks with Postgres TRUNCATE
    DatabaseCleaner.clean_with(:deletion)

    # Load essential seed data with explicit clearing for deterministic baseline
    def build_with_retry(times: 3)
      attempts = 0
      begin
        yield
      rescue ActiveRecord::Deadlocked
        attempts += 1
        retry if attempts < times
        raise
      end
    end

    build_with_retry { BetterTogether::AccessControlBuilder.build(clear: true) }
    build_with_retry { BetterTogether::NavigationBuilder.build(clear: true) }
    build_with_retry { BetterTogether::CategoryBuilder.build(clear: true) }
    build_with_retry { BetterTogether::SetupWizardBuilder.build(clear: true) }
    build_with_retry { BetterTogether::AgreementBuilder.build(clear: true) }
  end

  # Use deletion strategy for all tests to avoid FK constraint issues with PostgreSQL
  config.before do
    # Always use deletion strategy with essential table preservation
    # This avoids PostgreSQL FK constraint issues that truncation causes
    DatabaseCleaner.strategy = :deletion, { except: ESSENTIAL_TABLES }

    DatabaseCleaner.start

    # Clear Rails cache to prevent permission/data pollution between parallel workers
    # This is critical for RBAC specs that cache permission checks for 12 hours
    Rails.cache.clear
  end

  config.after do
    DatabaseCleaner.clean

    # Clear cache again after each test to ensure clean state
    Rails.cache.clear
  end

  # Reset locale to English after each test to prevent test isolation issues
  config.after do
    I18n.locale = I18n.default_locale
  end

  # Ensure essential data is available after JS tests
  config.after(:each, :js) do
    # Check if essential data exists, re-seed if missing
    unless BetterTogether::Role.exists?
      Rails.logger.debug '🔄 Re-seeding essential data after JS test'
      BetterTogether::AccessControlBuilder.build(clear: false)
      BetterTogether::NavigationBuilder.build(clear: false)
      BetterTogether::CategoryBuilder.build(clear: false)
      BetterTogether::SetupWizardBuilder.build(clear: false)
      BetterTogether::AgreementBuilder.build(clear: false)
    end
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    # Choose a test framework:
    with.test_framework :rspec

    # Or, choose the following (which implies all of the above):
    with.library :rails
  end
end

def create_table(table_name, **, &)
  ActiveRecord::Base.connection.create_table(table_name, **, &)
end

def drop_table(table_name, **)
  ActiveRecord::Base.connection.drop_table(table_name, **)
end

# Helper to ensure essential data is available in tests
def ensure_essential_data!
  return if BetterTogether::Role.exists?

  Rails.logger.warn '⚠️  Essential data missing, re-seeding...'
  load BetterTogether::Engine.root.join('db', 'seeds.rb')
end
