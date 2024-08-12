# frozen_string_literal: true

# app/builders/better_together/navigation_builder.rb

module BetterTogether
  # automates creation of important built-in navigation and pages
  class NavigationBuilder < Builder # rubocop:todo Metrics/ClassLength
    class << self
      def seed_data
        I18n.with_locale(:en) do
          build_header
          build_header_admin
          build_better_together
          build_footer

          create_unassociated_pages
        end
      end

      def build_better_together # rubocop:todo Metrics/MethodLength
        I18n.with_locale(:en) do # rubocop:todo Metrics/BlockLength
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
                content_en: ''
              },
              {
                title: 'About the Community Engine',
                slug: 'better-together/community-engine',
                published_at: DateTime.current,
                privacy: 'public',
                published: true,
                protected: true,
                template: 'better_together/static_pages/community_engine',
                content_en: ''
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
      end

      def build_footer # rubocop:todo Metrics/MethodLength
        I18n.with_locale(:en) do # rubocop:todo Metrics/BlockLength
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
                content_en: ''
              },
              {
                title: 'Privacy Policy',
                slug: 'privacy-policy',
                published_at: DateTime.current,
                privacy: 'public',
                published: true,
                protected: true,
                template: 'better_together/static_pages/privacy',
                content_en: ''
              },
              {
                title: 'Terms of Service',
                slug: 'terms-of-service',
                published_at: DateTime.current,
                privacy: 'public',
                published: true,
                protected: true,
                template: 'better_together/static_pages/terms_of_service',
                content_en: ''
              },
              {
                title: 'Code of Conduct',
                slug: 'code-of-conduct',
                published_at: DateTime.current,
                privacy: 'public',
                published: true,
                protected: true,
                template: 'better_together/static_pages/code_of_conduct',
                content_en: ''
              },
              {
                title: 'Accessibility',
                slug: 'accessibility',
                published_at: DateTime.current,
                privacy: 'public',
                published: true,
                protected: true,
                template: 'better_together/static_pages/accessibility',
                content_en: ''
              },
              {
                title: 'Contact',
                slug: 'contact',
                published_at: DateTime.current,
                privacy: 'public',
                published: true,
                protected: true,
                content_en: <<-HTML
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
      end

      def build_header # rubocop:todo Metrics/MethodLength
        I18n.with_locale(:en) do
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
                content_en: <<-HTML
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
      end

      # rubocop:todo Metrics/MethodLength
      def build_header_admin # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        I18n.with_locale(:en) do # rubocop:todo Metrics/BlockLength
          # Create Platform Header Admin Navigation Area and its Navigation Items
          ::BetterTogether::NavigationArea.create! do |area| # rubocop:todo Metrics/BlockLength
            area.name = 'Platform Header Admin'
            area.slug = 'platform-header-admin'
            area.visible = true
            area.protected = true

            # byebug
            # Create Admin Navigation Item
            admin_nav = area.navigation_items.build(
              title: 'Host',
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
                title: 'Dashboard',
                slug: 'host-dashboard',
                position: 0,
                item_type: 'link',
                url: ::BetterTogether::Engine.routes.url_helpers.host_dashboard_path
              },
              {
                title: 'Communities',
                slug: 'communities',
                position: 1,
                item_type: 'link',
                url: ::BetterTogether::Engine.routes.url_helpers.communities_path
              },
              {
                title: 'Navigation Areas',
                slug: 'navigation-areas',
                position: 2,
                item_type: 'link',
                url: ::BetterTogether::Engine.routes.url_helpers.navigation_areas_path
              },
              {
                title: 'Pages',
                slug: 'pages',
                position: 3,
                item_type: 'link',
                url: ::BetterTogether::Engine.routes.url_helpers.pages_path
              },
              {
                title: 'People',
                slug: 'people',
                position: 4,
                item_type: 'link',
                url: ::BetterTogether::Engine.routes.url_helpers.people_path
              },
              {
                title: 'Platforms',
                slug: 'platforms',
                position: 5,
                item_type: 'link',
                url: ::BetterTogether::Engine.routes.url_helpers.platforms_path
              },
              {
                title: 'Roles',
                slug: 'roles',
                position: 6,
                item_type: 'link',
                url: ::BetterTogether::Engine.routes.url_helpers.roles_path
              },
              {
                title: 'Resource Permissions',
                slug: 'resource_permissions',
                position: 7,
                item_type: 'link',
                url: ::BetterTogether::Engine.routes.url_helpers.resource_permissions_path
              }
            ]

            admin_nav_children.each do |child_attrs|
              admin_nav.children.build(child_attrs.merge(visible: true, protected: true, navigation_area: area))
            end
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
        I18n.with_locale(:en) do
          # Create Pages not associated with a navigation area
          ::BetterTogether::Page.create!(
            [
              {
                title: 'Home',
                slug: 'home-page',
                published_at: DateTime.current,
                privacy: 'public',
                published: true,
                protected: true,
                template: 'better_together/static_pages/community_engine',
                layout: 'layouts/better_together/full_width_page',
                content_en: ''
              },
              {
                title: 'Subprocessors',
                slug: 'subprocessors',
                published_at: DateTime.current,
                privacy: 'public',
                published: true,
                protected: true,
                template: 'better_together/static_pages/subprocessors',
                content_en: ''
              }
            ]
          )
        end
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
