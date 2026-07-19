# frozen_string_literal: true

module BetterTogether
  # Mints a fresh, platform-scoped Wizard + WizardStepDefinitions for a single
  # new-platform provisioning run. Unlike SetupWizardBuilder (which seeds one
  # global singleton Wizard row at db:seed time for the host platform), this
  # builder is called once per run, at the moment a draft Platform is created —
  # see NewPlatformSetupController#start.
  #
  # Phase 1 covered 3 steps (welcome, platform_identity, steward_account).
  # Phase 2 inserts the domain step between platform_identity and
  # steward_account. Later phases (invite_members, review_and_launch) insert
  # additional WizardStepDefinition rows with higher step_numbers — safe to do
  # without a migration, since each run mints its own Wizard/WizardStepDefinition
  # rows fresh rather than reusing seeded ones.
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
        name: 'Domain',
        description: 'Optionally add a subdomain alias or custom domain for the new platform.',
        identifier: 'domain',
        step_number: 3,
        message: 'Platform details saved! You can add an extra domain now, or skip this step.'
      },
      {
        name: 'Steward Account',
        description: 'Create the first steward account for the new platform.',
        identifier: 'steward_account',
        step_number: 4,
        form_class: '::BetterTogether::NewPlatformStewardForm',
        message: 'Next, create the steward account for this platform.'
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
