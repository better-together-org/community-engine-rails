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

    desc 'Reset navigation areas only (preserves pages)'
    task reset_navigation: :environment do
      BetterTogether::NavigationBuilder.reset_navigation_areas
    end

    desc 'Reset specific navigation area (usage: rake better_together:generate:reset_navigation_area[platform-header])'
    task :reset_navigation_area, [:slug] => :environment do |_t, args|
      if args[:slug].blank?
        puts 'Error: Please provide a navigation area slug'
        puts 'Available slugs: platform-header, platform-host, better-together, platform-footer'
        puts 'Usage: rake better_together:generate:reset_navigation_area[platform-header]'
        exit 1
      end

      BetterTogether::NavigationBuilder.reset_navigation_area(args[:slug])
    end

    desc 'List all navigation areas and items'
    task list_navigation: :environment do
      puts "\nNavigation Areas:"
      puts '=' * 80

      BetterTogether::NavigationArea.i18n.order(:slug).each do |area|
        puts "\nArea: #{area.name}"
        puts "  Slug: #{area.slug}"
        puts "  Visible: #{area.visible}"
        puts "  Protected: #{area.protected}"
        puts "  Items: #{area.navigation_items.count}"

        next unless area.navigation_items.any?

        puts '  Navigation Items:'
        area.navigation_items.where(parent_id: nil).order(:position).each do |item|
          puts "    - #{item.title} (#{item.item_type})"
          next unless item.children.any?

          item.children.order(:position).each do |child|
            puts "      └─ #{child.title} (#{child.item_type})"
          end
        end
      end
      puts "\n#{'=' * 80}"
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
