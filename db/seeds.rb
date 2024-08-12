# frozen_string_literal: true

# db/seeds.rb

BetterTogether::AccessControlBuilder.build(clear: true)

BetterTogether::GeographyBuilder.build(clear: true)

BetterTogether::NavigationBuilder.build(clear: true)

BetterTogether::SetupWizardBuilder.build(clear: true)
