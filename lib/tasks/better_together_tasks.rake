# lib/tasks/better_together_tasks.rake
namespace :better_together do
  desc "Load seed data for BetterTogether"
  task load_seed: :environment do
    load BetterTogether::Engine.root.join('db', 'seeds.rb')
  end

  desc "Generate default navigation areas, items, and pages"
  task generate_navigation_and_pages: :environment do
    # Clear existing data - Use with caution!
    BetterTogether::Page.destroy_all
    BetterTogether::NavigationItem.delete_all
    BetterTogether::NavigationArea.delete_all

    # Create platform header pages
    header_pages = BetterTogether::Page.create([
      {
        title: 'About',
        slug: 'about',
        published_at: DateTime.current,
        page_privacy: 'public',
        published: true,
        protected: true,
        content: <<-HTML
        <h1 class="page-header mb-3">About</h1>
        <p>This is a default about page. Be sure to write a real one!</p>
        HTML
      }
    ])

    # Create Platform Header Navigation Area
    BetterTogether::NavigationArea.create do |area|
      area.name = "Platform Header"
      area.slug = "platform-header"
      area.visible = true
      area.protected = true

      header_pages.each_with_index do |page, index|
        page_nav_item = area.navigation_items.build(
          title: page.title,
          slug: page.slug,
          position: index,
          visible: true,
          protected: true,
          item_type: 'link',
          url: "",
          linkable: page
        )
      end
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

    # Create Platform Footer Pages
    footer_pages = BetterTogether::Page.create([
      {
        title: 'Privacy Policy',
        slug: 'privacy-policy',
        published_at: DateTime.current,
        page_privacy: 'public',
        published: true,
        protected: true,
        template: "better_together/static_pages/privacy",
        content: ""
      },
      {
        title: 'Terms of Service',
        slug: 'terms-of-service',
        published_at: DateTime.current,
        page_privacy: 'public',
        published: true,
        protected: true,
        template: "better_together/static_pages/terms_of_service",
        content: ""
      },
      {
        title: 'Code of Conduct',
        slug: 'code-of-conduct',
        published_at: DateTime.current,
        page_privacy: 'public',
        published: true,
        protected: true,
        template: "better_together/static_pages/code_of_conduct",
        content: ""
      },
      {
        title: 'Accessibility',
        slug: 'accessibility',
        published_at: DateTime.current,
        page_privacy: 'public',
        published: true,
        protected: true,
        template: "better_together/static_pages/accessibility",
        content: ""
      },
      {
        title: 'Contact',
        slug: 'contact',
        published_at: DateTime.current,
        page_privacy: 'public',
        published: true,
        protected: true,
        content: <<-HTML
        <h1 class="page-header mb-3">Contact Us</h1>
        <p>This is a default contact page for your platform. Be sure to write a real one!</p>
        HTML
      }
    ])

    # Create Platform Header AdminFooter Navigation Area and its Navigation Items
    BetterTogether::NavigationArea.create do |area|
      area.name = "Platform Footer"
      area.slug = "platform-footer"
      area.visible = true
      area.protected = true

      footer_pages.each_with_index do |page, index|
        page_nav_item = area.navigation_items.build(
          title: page.title,
          slug: page.slug,
          position: index,
          visible: true,
          protected: true,
          item_type: 'link',
          url: "",
          linkable: page
        )
      end
    end

    # Create Better Together Nav Area
    better_together_pages = BetterTogether::Page.create([
      {
        title: 'What is Better Together?',
        slug: 'better-together',
        published_at: DateTime.current,
        page_privacy: 'public',
        published: true,
        protected: true,
        template: 'better_together/static_pages/better_together',
        content: ""
      },
      {
        title: 'About the Community Engine',
        slug: 'better-together/community-engine',
        published_at: DateTime.current,
        page_privacy: 'public',
        published: true,
        protected: true,
        template: 'better_together/static_pages/community_engine',
        content: ""
      }
    ])

    BetterTogether::NavigationArea.create do |area|
      area.name = "Better Together"
      area.slug = "better-together"
      area.visible = true
      area.protected = true

      # Create Admin Navigation Item
      better_together_nav_item = area.navigation_items.build(
        title: "Powered with <3 by Better Together",
        slug: "better-together-nav",
        position: 0,
        visible: true,
        protected: true,
        item_type: 'dropdown',
        url: "#"
      )

      # Add children to Better Together Navigation Item

      better_together_pages.each_with_index do |page, index|
        page_nav_item = better_together_nav_item.children.build(
          navigation_area: area,  
          title: page.title,
          slug: page.slug,
          position: index,
          visible: true,
          protected: true,
          item_type: 'link',
          url: "",
          linkable: page
        )
      end
    end

    # Create Pages not associated with a navigation area
    unassociated_pages = BetterTogether::Page.create([
      {
        title: 'Subprocessors',
        slug: 'subprocessors',
        published_at: DateTime.current,
        page_privacy: 'public',
        published: true,
        protected: true,
        template: "better_together/static_pages/subprocessors",
        content: ""
      }
    ])
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
