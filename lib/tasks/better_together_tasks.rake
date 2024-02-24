# lib/tasks/better_together_tasks.rake
namespace :better_together do
  desc "Load seed data for BetterTogether"
  task load_seed: :environment do
    load BetterTogether::Engine.root.join('db', 'seeds.rb')
  end

  desc "Generate default navigation areas, items, and pages"
  task generate_navigation_and_pages: :environment do
    BetterTogether::NavigationBuilder.build(clear: true)
  end

  desc "Generate setup wizard and step definitions"
  task generate_setup_wizard: :environment do
    BetterTogether::SetupWizardBuilder.build(clear: true)
  end

end
