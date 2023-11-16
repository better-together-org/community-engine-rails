# db/seeds.rb

BetterTogether::Wizard.destroy_all
BetterTogether::Wizard.create do |wizard|
  wizard.name = 'Host Setup Wizard'
  wizard.identifier = 'host_setup'
  wizard.description = 'Initial setup wizard for configuring the host platform.'
  wizard.host = true
  wizard.max_completions = 1
  wizard.success_message = 'Thank you! You have finished setting up your Better Together platform! Enjoy!',
  wizard.success_path = '/'

  # Other default attributes are set by Rails (like timestamps)

  # Step 1: Platform Details
  wizard.wizard_step_definitions.build(
    name: 'Platform Details',
    description: 'Set up basic details of the platform, including name and URL.',
    identifier: 'platform_details',
    step_number: 1,
    form_class: '::BetterTogether::HostPlatformDetailsForm'
    # Template and form_class can be set as needed
  )

  # Step 2: Platform Administrator Creation
  wizard.wizard_step_definitions.build(
    name: 'Administrator Account',
    description: 'Create the first administrator account for managing the platform.',
    identifier: 'admin_creation',
    step_number: 2,
    form_class: '::BetterTogether::HostPlatformAdministratorForm'
    # Template and form_class can be set as needed
  )
end
