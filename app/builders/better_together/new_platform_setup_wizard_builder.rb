# frozen_string_literal: true

module BetterTogether
  # Mints a fresh, platform-scoped Wizard + WizardStepDefinitions for a single
  # new-platform provisioning run. Unlike SetupWizardBuilder (which seeds one
  # global singleton Wizard row at db:seed time for the host platform), this
  # builder is called once per run, at the moment a draft Platform is created —
  # see NewPlatformSetupController#start.
  #
  # Phase 1 covered 3 steps (welcome, platform_identity, steward_account).
  # Phase 2 inserted the domain step between platform_identity and
  # steward_account. Phase 4 (this revision) adds the final review_and_launch
  # step at step_number 6. Phase 3 (invite_members, step_number 5) is being
  # built in parallel on a sibling branch and is deliberately NOT present
  # here — the step_number gap (4 -> 6, skipping 5) is intentional so that
  # once both branches merge, invite_members sorts correctly between
  # steward_account and review_and_launch without renumbering anything.
  # wizard_step_definitions.ordered (scope: order(:step_number)) tolerates
  # gaps fine, and step_number uniqueness is scoped per-Wizard row, so this
  # is safe to ship standalone. See the implementation plan's phase
  # sequencing table for the full picture.
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
      },
      {
        name: 'Review & Launch',
        description: 'Review everything you\'ve set up, then launch the new platform.',
        identifier: 'review_and_launch',
        step_number: 6,
        message: 'Almost there! Review your new platform\'s details below, then launch it.'
      }
    ].freeze

    class << self
      def build(platform:, success_path:, success_message:)
        wizard = build_wizard(platform:, success_path:, success_message:)
        # platform_id is explicitly set to the draft platform here (not left to
        # PlatformScoped's before_validation fallback, which would resolve to
        # Current.platform — the HOST platform during a normal request, not the
        # draft being provisioned). Every run mints WizardStepDefinition rows
        # with the same identifiers ("welcome", "platform_identity", etc.), so
        # without correct per-run platform scoping here, the second-ever
        # provisioning run would collide with the first's rows under the
        # platform-scoped unique index — see the accompanying migration
        # (20260719160000) for the index-side half of this fix and the
        # production-severity bug it corrects.
        STEP_DEFINITIONS.each { |attrs| wizard.wizard_step_definitions.create!(attrs.merge(platform_id: platform.id)) }
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
