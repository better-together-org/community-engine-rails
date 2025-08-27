# frozen_string_literal: true

module SeedHelper
  # Ensures essential seed data is available for tests
  def self.ensure_seeded!
    return if @seeded && essential_data_exists?

    load_seeds_safely
    @seeded = true
  end

  def self.essential_data_exists?
    BetterTogether::Role.exists? &&
      BetterTogether::ResourcePermission.exists? &&
      BetterTogether::NavigationArea.exists?
  rescue ActiveRecord::StatementInvalid
    # Tables might not exist during migration tests
    false
  end

  def self.load_seeds_safely
    Rails.logger.debug '🌱 Loading Better Together seeds safely...'

    # Always use clear: false to avoid FK violations in tests
    BetterTogether::AccessControlBuilder.build(clear: false)
    BetterTogether::NavigationBuilder.build(clear: false)
    BetterTogether::CategoryBuilder.build(clear: false)
    BetterTogether::SetupWizardBuilder.build(clear: false)
    BetterTogether::AgreementBuilder.build(clear: false)
  rescue StandardError => e
    Rails.logger.warn "⚠️  Issue loading seeds safely: #{e.message}"
    # If individual builders fail, at least try to create minimal seed data
    create_minimal_seeds
  end

  def self.create_minimal_seeds
    Rails.logger.debug '🌱 Creating minimal seed data...'

    # Create essential roles if they don't exist
    unless BetterTogether::Role.exists?
      BetterTogether::Role.create!(
        identifier: 'platform_manager',
        name: 'Platform Manager',
        resource_type: 'BetterTogether::Platform',
        lock_version: 0
      )

      BetterTogether::Role.create!(
        identifier: 'community_manager',
        name: 'Community Manager',
        resource_type: 'BetterTogether::Community',
        lock_version: 0
      )
    end

    # Create essential navigation area if it doesn't exist
    unless BetterTogether::NavigationArea.exists?
      BetterTogether::NavigationArea.create!(
        identifier: 'header',
        name: 'Header',
        lock_version: 0
      )
    end
  rescue StandardError => e
    Rails.logger.error "❌ Failed to create minimal seeds: #{e.message}"
    # Continue anyway - some tests might still pass
  end

  def self.load_seeds
    Rails.logger.debug '🌱 Loading Better Together seeds from file...'
    load BetterTogether::Engine.root.join('db', 'seeds.rb')
  end

  # Reset seeded flag (useful for tests that need fresh seeds)
  def self.reset!
    @seeded = false
  end
end

# Make available in all specs, but only once per example
RSpec.configure do |config|
  config.before do
    SeedHelper.ensure_seeded!
  end
end
