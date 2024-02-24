module BetterTogether
  module SetupWizardBuilder
    class << self
      def build(clear: false)
        Rails.logger.debug 'build'
        clear_existing if clear

        BetterTogether::Wizard.create! do |wizard|
          wizard.name = 'Host Setup Wizard'
          wizard.identifier = 'host_setup'
          wizard.description = 'Initial setup wizard for configuring the host platform.'
          wizard.protected = true
          wizard.max_completions = 1
          wizard.success_message = 'Thank you! You have finished setting up your Better Together platform! Platform administrator account created successfully! Please check the email that you provided to confirm the email address before you can sign in.'
          wizard.success_path = '/'

          # Other default attributes are set by Rails (like timestamps)

          # Step 1: Platform Details
          wizard.wizard_step_definitions.build(
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
          wizard.wizard_step_definitions.build(
            name: 'Administrator Account',
            description: 'Create the first administrator account for managing the platform.',
            identifier: 'admin_creation',
            protected: true,
            step_number: 2,
            form_class: '::BetterTogether::HostPlatformAdministratorForm',
            message: 'Platform details saved successfully! Next, please configure the administrator account details below.'
            # Template and form_class can be set as needed
          )
        end
      end

      def clear_existing
        BetterTogether::WizardStep.destroy_all
        BetterTogether::WizardStepDefinition.destroy_all
        BetterTogether::Wizard.destroy_all
      end
    end
  end
end
