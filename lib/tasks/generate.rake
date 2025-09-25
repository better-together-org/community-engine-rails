# frozen_string_literal: true

namespace :better_together do # rubocop:todo Metrics/BlockLength
  namespace :generate do # rubocop:todo Metrics/BlockLength
    desc 'Generate access control'
    task access_control: :environment do
      BetterTogether::AccessControlBuilder.build(clear: true)
    end

    desc 'Generate default navigation areas, items, and pages'
    task navigation_and_pages: :environment do
      BetterTogether::NavigationBuilder.build(clear: true)
    end

    desc 'Generate setup wizard and step definitions'
    task setup_wizard: :environment do
      BetterTogether::SetupWizardBuilder.build(clear: true)
    end

    desc 'Generate default Agreement data'
    task agreements: :environment do
      BetterTogether::AgreementBuilder.build(clear: true)
    end

    desc 'Generate default event and Joatu categories'
    task categories: :environment do
      BetterTogether::CategoryBuilder.build(clear: true)
    end

    desc 'Generate realistic Joatu demo data (CLEAR=1 to reset demo)'
    task joatu_demo: :environment do
      if ENV['CLEAR'].to_s == '1'
        puts 'Clearing existing Joatu demo data...'
        BetterTogether::JoatuDemoBuilder.clear_existing
      end

      puts 'Seeding Joatu demo data...'
      BetterTogether::JoatuDemoBuilder.build
      puts 'Done. Try browsing offers/requests and agreements in the demo community.'
    end

    desc 'Generate external OAuth provider platforms'
    task external_platforms: :environment do
      if ENV['CLEAR'].to_s == '1'
        puts 'Clearing existing external platforms...'
        BetterTogether::ExternalPlatformBuilder.clear_existing
      end

      puts 'Generating external OAuth provider platforms...'
      BetterTogether::ExternalPlatformBuilder.build(clear: ENV['CLEAR'].to_s == '1')
      puts 'Done. External OAuth platforms are ready for authentication.'
    end
  end
end
