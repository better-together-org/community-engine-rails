# frozen_string_literal: true

# app/builders/better_together/navigation_builder.rb

module BetterTogether
  # automates creation of important built-in navigation and pages
  class NavigationBuilder < Builder # rubocop:todo Metrics/ClassLength
    class << self
      def seed_data
        build_header
        build_header_admin
        build_better_together
        build_footer

        create_unassociated_pages
      end

      def build_better_together # rubocop:todo Metrics/MethodLength
        # Create Better Together Nav Area
        better_together_pages = ::BetterTogether::Page.create!(
          [
            {
              title: 'What is Better Together?',
              slug: 'better-together',
              published_at: DateTime.current,
              privacy: 'public',
              published: true,
              protected: true,
              template: 'better_together/static_pages/better_together',
              content: ''
            },
            {
              title: 'About the Community Engine',
              slug: 'better-together/community-engine',
              published_at: DateTime.current,
              privacy: 'public',
              published: true,
              protected: true,
              template: 'better_together/static_pages/community_engine',
              content: ''
            }
          ]
        )

        ::BetterTogether::NavigationArea.create! do |area|
          area.name = 'Better Together'
          area.slug = 'better-together'
          area.visible = true
          area.protected = true

          # Create Admin Navigation Item
          better_together_nav_item = area.navigation_items.build(
            title: 'Powered with <3 by Better Together',
            slug: 'better-together-nav',
            position: 0,
            visible: true,
            protected: true,
            item_type: 'dropdown',
            url: '#'
          )

          # Add children to Better Together Navigation Item
          better_together_nav_item.build_children(better_together_pages, area)
        end
      end

      def build_footer # rubocop:todo Metrics/MethodLength
        # Create Platform Footer Pages
        footer_pages = ::BetterTogether::Page.create!(
          [
            {
              title: 'FAQ',
              slug: 'faq',
              published_at: DateTime.current,
              privacy: 'public',
              published: true,
              protected: true,
              template: 'better_together/static_pages/faq',
              content: ''
            },
            {
              title: 'Privacy Policy',
              slug: 'privacy-policy',
              published_at: DateTime.current,
              privacy: 'public',
              published: true,
              protected: true,
              template: 'better_together/static_pages/privacy',
              content: ''
            },
            {
              title: 'Terms of Service',
              slug: 'terms-of-service',
              published_at: DateTime.current,
              privacy: 'public',
              published: true,
              protected: true,
              template: 'better_together/static_pages/terms_of_service',
              content: ''
            },
            {
              title: 'Code of Conduct',
              slug: 'code-of-conduct',
              published_at: DateTime.current,
              privacy: 'public',
              published: true,
              protected: true,
              template: 'better_together/static_pages/code_of_conduct',
              content: ''
            },
            {
              title: 'Accessibility',
              slug: 'accessibility',
              published_at: DateTime.current,
              privacy: 'public',
              published: true,
              protected: true,
              template: 'better_together/static_pages/accessibility',
              content: ''
            },
            {
              title: 'Contact',
              slug: 'contact',
              published_at: DateTime.current,
              privacy: 'public',
              published: true,
              protected: true,
              content: <<-HTML
              <h1 class="page-header mb-3">Contact Us</h1>
              <p>This is a default contact page for your platform. Be sure to write a real one!</p>
              HTML
            }
          ]
        )

        # Create Platform Footer Navigation Area and its Navigation Items
        ::BetterTogether::NavigationArea.create! do |area|
          area.name = 'Platform Footer'
          area.slug = 'platform-footer'
          area.visible = true
          area.protected = true

          area.build_page_navigation_items(footer_pages)
        end
      end

      def build_header # rubocop:todo Metrics/MethodLength
        # Create platform header pages
        header_pages = ::BetterTogether::Page.create(
          [
            {
              title: 'About',
              slug: 'about',
              published_at: DateTime.current,
              privacy: 'public',
              published: true,
              protected: true,
              content: <<-HTML
              <h1 class="page-header mb-3">About</h1>
              <p>This is a default about page. Be sure to write a real one!</p>
              HTML
            }
          ]
        )

        # Create Platform Header Navigation Area
        ::BetterTogether::NavigationArea.create! do |area|
          area.name = 'Platform Header'
          area.slug = 'platform-header'
          area.visible = true
          area.protected = true

          area.build_page_navigation_items(header_pages)
        end
      end

      # rubocop:todo Metrics/MethodLength
      def build_header_admin # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        # Create Platform Header Admin Navigation Area and its Navigation Items
        ::BetterTogether::NavigationArea.create! do |area| # rubocop:todo Metrics/BlockLength
          area.name = 'Platform Header Admin'
          area.slug = 'platform-header-admin'
          area.visible = true
          area.protected = true

          # Create Admin Navigation Item
          admin_nav = area.navigation_items.build(
            title: 'Admin',
            slug: 'admin-nav',
            position: 0,
            visible: true,
            protected: true,
            item_type: 'dropdown',
            url: '#'
          )

          # Add children to Admin Navigation Item
          admin_nav_children = [
            {
              title: 'Navigation Areas',
              slug: 'navigation-areas',
              position: 0,
              item_type: 'link',
              url: ::BetterTogether::Engine.routes.url_helpers.navigation_areas_path
            },
            {
              title: 'Pages',
              slug: 'pages',
              position: 1,
              item_type: 'link',
              url: ::BetterTogether::Engine.routes.url_helpers.pages_path
            },
            {
              title: 'Roles',
              slug: 'roles',
              position: 2,
              item_type: 'link',
              url: ::BetterTogether::Engine.routes.url_helpers.roles_path
            },
            {
              title: 'Resource Permissions',
              slug: 'resource_permissions',
              position: 3,
              item_type: 'link',
              url: ::BetterTogether::Engine.routes.url_helpers.resource_permissions_path
            }
          ]

          admin_nav_children.each do |child_attrs|
            admin_nav.children.build(child_attrs.merge(visible: true, protected: true, navigation_area: area))
          end
        end
      end
      # rubocop:enable Metrics/MethodLength

      # Clear existing data - Use with caution!
      def clear_existing
        delete_pages
        delete_navigation_items
        delete_navigation_areas
      end

      def create_unassociated_pages # rubocop:todo Metrics/MethodLength
        # Create Pages not associated with a navigation area
        ::BetterTogether::Page.create!(
          [
            {
              title: 'Subprocessors',
              slug: 'subprocessors',
              published_at: DateTime.current,
              privacy: 'public',
              published: true,
              protected: true,
              template: 'better_together/static_pages/subprocessors',
              content: ''
            }
          ]
        )
      end

      def delete_pages
        ::BetterTogether::Page.delete_all
      end

      def delete_navigation_areas
        ::BetterTogether::NavigationArea.delete_all
      end

      def delete_navigation_items
        ::BetterTogether::NavigationItem.delete_all
      end
    end
  end
end
