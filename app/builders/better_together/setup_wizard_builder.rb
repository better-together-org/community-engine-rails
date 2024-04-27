# frozen_string_literal: true

module BetterTogether
  # A utility to automatically create seed data for default wizards (eg: setup wizard)
  class SetupWizardBuilder < Builder
    class << self
      # rubocop:todo Metrics/MethodLength
      def seed_data # rubocop:todo Metrics/MethodLength
        # byebug

        setup_wizard = ::BetterTogether::Wizard.create!(
          name: 'Host Setup Wizard',
          identifier: 'host_setup',
          description: 'Initial setup wizard for configuring the host platform.',
          protected: true,
          max_completions: 1,
          success_message: 'Thank you! You have finished setting up your Better Together platform! ' \
                           'Platform administrator account created successfully! Please check the email that you provided to confirm the ' \
                           'email address before you can sign in.',
          success_path: '/'
        )

        # byebug

        # Step 1: Platform Details
        setup_wizard.wizard_step_definitions.create!(
          name: 'Platform Details',
          description: 'Set up basic details of the platform, including name and URL.',
          identifier: 'platform_details',
          protected: true,
          step_number: 1,
          form_class: '::BetterTogether::HostPlatformDetailsForm',
          message: 'Please configure your platform\'s details below'
          # Template and form_class can be set as needed
        )

        # Step 2: Platform Administrator Creation
        setup_wizard.wizard_step_definitions.create!(
          name: 'Administrator Account',
          description: 'Create the first administrator account for managing the platform.',
          identifier: 'admin_creation',
          protected: true,
          step_number: 2,
          form_class: '::BetterTogether::HostPlatformAdministratorForm',
          message: 'Platform details saved successfully! Next, please configure the administrator account
            details below.'
          # Template and form_class can be set as needed
        )
      end
      # rubocop:enable Metrics/MethodLength

      def clear_existing
        ::BetterTogether::WizardStep.delete_all
        ::BetterTogether::WizardStepDefinition.delete_all
        ::BetterTogether::Wizard.delete_all
      end
    end
  end
end
