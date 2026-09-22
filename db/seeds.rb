# frozen_string_literal: true

# db/seeds.rb

# Ensure a host platform record exists first — builders (NavigationBuilder, etc.)
# create records with a platform_id FK, so the platform must exist before they run.
# PLATFORM_NAME / PLATFORM_URL / PLATFORM_TIME_ZONE may be set via env.
BetterTogether::Platform.find_or_create_by!(host: true) do |platform|
  platform.name       = ENV.fetch('PLATFORM_NAME', 'Community Engine')
  platform.url        = ENV.fetch('PLATFORM_URL',  'http://localhost:3000')
  platform.external   = false
  platform.privacy    = 'private'
  platform.time_zone  = ENV.fetch('PLATFORM_TIME_ZONE', Time.zone.tzinfo.identifier)
  platform.protected           = true
  platform.requires_invitation = true
end

BetterTogether::AccessControlBuilder.build(clear: true)

BetterTogether::NavigationBuilder.build(clear: true)

BetterTogether::CategoryBuilder.build(clear: true)

BetterTogether::SetupWizardBuilder.build(clear: true)

BetterTogether::AgreementBuilder.build(clear: true)

# Geography reference data (Continents/Countries/States/Regions/Settlements) is
# intentionally NOT auto-seeded here. GeographyBuilder.build(clear: true) bulk-creates
# ~230+ records, each of which triggers live Nominatim geocoding (see geocodes_self on
# those five models) — running that automatically on every seed/deploy would fire an
# unthrottled burst of external HTTP calls violating Nominatim's usage policy. Install
# it deliberately instead:
#   bin/rails better_together:geography:seed_reference_data
#   bin/rails better_together:geography:import_geocodes
# (a dedicated seed-catalog admin UI for this is planned as a follow-up)
