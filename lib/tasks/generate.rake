namespace :better_together do
  namespace :generate do
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
  end
end
