# frozen_string_literal: true

module BetterTogether
  # Mints a fresh, platform-scoped Wizard + WizardStepDefinitions for a single
  # new-platform provisioning run. Unlike SetupWizardBuilder (a global
  # singleton seeded once for the host platform), this runs once per
  # provisioning attempt, at draft Platform creation time — see
  # NewPlatformSetupController#start.
  class NewPlatformSetupWizardBuilder
    IDENTIFIER = 'new_platform_setup'

    STEP_DEFINITIONS = [
      {
        name: 'Welcome',
        description: 'Choose a language and see what this wizard will set up.',
        identifier: 'welcome',
        step_number: 1,
        message: "Let's get your new platform set up."
      },
      {
        name: 'Platform Identity',
        description: 'Set the new platform\'s name, description, privacy, and time zone.',
        identifier: 'platform_identity',
        step_number: 2,
        form_class: '::BetterTogether::NewPlatformIdentityForm',
        message: 'Please configure the new platform\'s details below.'
      },
      {
        name: 'Steward Account',
        description: 'Create the first steward account for the new platform.',
        identifier: 'steward_account',
        step_number: 3,
        form_class: '::BetterTogether::NewPlatformStewardForm',
        message: 'Platform details saved! Next, create the steward account for this platform.'
      }
    ].freeze

    class << self
      def build(platform:, success_path:, success_message:)
        wizard = build_wizard(platform:, success_path:, success_message:)
        STEP_DEFINITIONS.each { |attrs| wizard.wizard_step_definitions.create!(attrs) }
        wizard
      end

      private

      def build_wizard(platform:, success_path:, success_message:)
        ::BetterTogether::Wizard.create!(
          name: 'New Platform Setup Wizard',
          identifier: IDENTIFIER,
          description: 'Provisions a new tenant platform: identity, and first steward account.',
          platform:,
          protected: false,
          max_completions: 1,
          success_message:,
          success_path:
        )
      end
    end
  end
end
