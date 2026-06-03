# frozen_string_literal: true

# db/seeds.rb

# Ensure a host platform record exists first — builders (NavigationBuilder, etc.)
# create records with a platform_id FK, so the platform must exist before they run.
# PLATFORM_NAME / PLATFORM_URL / PLATFORM_TIME_ZONE may be set via env.
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
