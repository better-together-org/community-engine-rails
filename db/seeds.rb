# frozen_string_literal: true

# db/seeds.rb

# Ensure a host platform record exists first — NavigationBuilder, CategoryBuilder,
# and other builders create Page/NavigationItem records that require a platform.
# PLATFORM_URL should be set to the public base URL of this deployment (e.g.
# https://staging.example.com). Defaults to localhost for local dev.
BetterTogether::Platform.find_or_create_by!(host: true) do |platform|
  platform.name       = ENV.fetch('PLATFORM_NAME', 'Community Engine')
  platform.url        = ENV.fetch('PLATFORM_URL',  'http://localhost:3000')
  platform.external   = false
  platform.privacy    = 'public'
  platform.time_zone  = ENV.fetch('PLATFORM_TIME_ZONE', 'UTC')
end

BetterTogether::AccessControlBuilder.build(clear: true)

# TODO: re-enable once duplicate community issue is resolved
# BetterTogether::GeographyBuilder.build(clear: true)

BetterTogether::NavigationBuilder.build(clear: true)

BetterTogether::CategoryBuilder.build(clear: true)

BetterTogether::SetupWizardBuilder.build(clear: true)

BetterTogether::AgreementBuilder.build(clear: true)
