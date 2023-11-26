# lib/tasks/better_together_tasks.rake
namespace :better_together do
  desc "Load seed data for BetterTogether"
  task load_seed: :environment do
    load BetterTogether::Engine.root.join('db', 'seeds.rb')
  end

  desc "Generate default navigation areas and items"
  task generate_navigation: :environment do
    # Clear existing data - Use with caution!
    BetterTogether::NavigationItem.delete_all
    BetterTogether::NavigationArea.delete_all

    # Create Platform Header Navigation Area
    BetterTogether::NavigationArea.create do |area|
      area.name = "Platform Header"
      area.slug = "platform-header"
      area.visible = true
      area.protected = true
    end

    # Create Platform Header Admin Navigation Area and its Navigation Items
    BetterTogether::NavigationArea.create do |area|
      area.name = "Platform Header Admin"
      area.slug = "platform-header-admin"
      area.visible = true
      area.protected = true

      # Create Admin Navigation Item
      admin_nav = area.navigation_items.build(
        title: "Admin",
        slug: "admin-nav",
        position: 0,
        visible: true,
        protected: true,
        item_type: 'dropdown',
        url: "#"
      )

      # Add children to Admin Navigation Item
      admin_nav_children = [
        { title: "Navigation Areas", slug: "navigation-areas", position: 0, item_type: 'link', url: "http://localhost:3000/bt/navigation_areas" },
        { title: "Pages", slug: "pages", position: 1, item_type: 'link', url: "http://localhost:3000/bt/pages" }
      ]

      admin_nav_children.each do |child_attrs|
        admin_nav.children.build(child_attrs.merge(visible: true, protected: true, navigation_area: area))
      end
    end
  end

  desc "Generate setup wizard and step definitions"
  task generate_setup_wizard: :environment do
    BetterTogether::WizardStep.destroy_all
    BetterTogether::WizardStepDefinition.destroy_all
    BetterTogether::Wizard.destroy_all

    BetterTogether::Wizard.create do |wizard|
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
end
