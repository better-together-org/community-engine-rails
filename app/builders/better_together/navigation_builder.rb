# frozen_string_literal: true

# app/builders/better_together/navigation_builder.rb

module BetterTogether
  # automates creation of important built-in navigation and pages
  class NavigationBuilder < Builder # rubocop:todo Metrics/ClassLength
    class << self
      def seed_data
        I18n.with_locale(:en) do
          build_header
          build_host
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
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/better_together',
                content_en: ''
              },
              {
                title: 'About the Community Engine',
                slug: 'better-together/community-engine',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/community_engine',
                content_en: ''
              }
            ]
          )

          area = ::BetterTogether::NavigationArea.create! do |area|
            area.name = 'Better Together'
            area.slug = 'better-together'
            area.visible = true
            area.protected = true
          end

          # Create Host Navigation Item
          better_together_nav_item = area.navigation_items.create!(
            title: 'Powered with <3 by Better Together',
            slug: 'better-together-nav',
            position: 0,
            visible: true,
            protected: true,
            item_type: 'dropdown',
            url: '#'
          )

          # Add children to Better Together Navigation Item
          better_together_nav_item.build_children(better_together_pages, area.reload)

          area.save!
        end
      end

      def build_footer # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
        I18n.with_locale(:en) do # rubocop:todo Metrics/BlockLength
          # Create Platform Footer Pages
          footer_pages = ::BetterTogether::Page.create!(
            [
              {
                title: 'FAQ',
                slug: 'faq',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/faq',
                content_en: ''
              },
              {
                title: 'Privacy Policy',
                slug: 'privacy-policy',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/privacy',
                content_en: ''
              },
              {
                title: 'Terms of Service',
                slug: 'terms-of-service',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/terms_of_service',
                content_en: ''
              },
              {
                title: 'Code of Conduct',
                slug: 'code-of-conduct',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/code_of_conduct',
                content_en: ''
              },
              {
                title: 'Accessibility',
                slug: 'accessibility',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/accessibility',
                content_en: ''
              },
              {
                title: 'Contact',
                slug: 'contact',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                content_en: <<-HTML
                <h1 class="page-header mb-3">Contact Us</h1>
                <p>This is a default contact page for your platform. Be sure to write a real one!</p>
                HTML
              }
            ]
          )

          # Create Platform Footer Navigation Area and its Navigation Items
          area = ::BetterTogether::NavigationArea.create! do |area|
            area.name = 'Platform Footer'
            area.slug = 'platform-footer'
            area.visible = true
            area.protected = true
          end

          area.reload.build_page_navigation_items(footer_pages)

          area.save!
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
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                content_en: <<-HTML
                <h1 class="page-header mb-3">About</h1>
                <p>This is a default about page. Be sure to write a real one!</p>
                HTML
              }
            ]
          )

          # Create Platform Header Navigation Area
          area = ::BetterTogether::NavigationArea.create! do |area|
            area.name = 'Platform Header'
            area.slug = 'platform-header'
            area.visible = true
            area.protected = true
          end

          area.build_page_navigation_items(header_pages)

          area.save!
        end
      end

      # rubocop:todo Metrics/MethodLength
      def build_host # rubocop:todo Metrics/MethodLength
        I18n.with_locale(:en) do # rubocop:todo Metrics/BlockLength
          # Create Platform Header Host Navigation Area and its Navigation Items
          area = ::BetterTogether::NavigationArea.create! do |area| # rubocop:todo Metrics/BlockLength
            area.name = 'Platform Host'
            area.slug = 'platform-host'
            area.visible = true
            area.protected = true
          end

          # byebug
          # Create Host Navigation Item
          host_nav = area.navigation_items.create!(
            title: 'Host',
            slug: 'host-nav',
            position: 0,
            visible: true,
            protected: true,
            item_type: 'dropdown',
            url: '#'
          )

          # Add children to Host Navigation Item
          host_nav_children = [
            {
              title: 'Dashboard',
              slug: 'host-dashboard',
              position: 0,
              item_type: 'link',
              route_name: 'host_dashboard_path'
            },
            {
              title: 'Communities',
              slug: 'communities',
              position: 1,
              item_type: 'link',
              route_name: 'communities_path'
            },
            {
              title: 'Navigation Areas',
              slug: 'navigation-areas',
              position: 2,
              item_type: 'link',
              route_name: 'navigation_areas_path'
            },
            {
              title: 'Pages',
              slug: 'pages',
              position: 3,
              item_type: 'link',
              route_name: 'pages_path'
            },
            {
              title: 'People',
              slug: 'people',
              position: 4,
              item_type: 'link',
              route_name: 'people_path'
            },
            {
              title: 'Platforms',
              slug: 'platforms',
              position: 5,
              item_type: 'link',
              route_name: 'platforms_path'
            },
            {
              title: 'Roles',
              slug: 'roles',
              position: 6,
              item_type: 'link',
              route_name: 'roles_path'
            },
            {
              title: 'Resource Permissions',
              slug: 'resource_permissions',
              position: 7,
              item_type: 'link',
              route_name: 'resource_permissions_path'
            }
          ]

          host_nav_children.each do |child_attrs|
            host_nav.children.create!(child_attrs.merge(visible: true, protected: true, navigation_area: area))
          end

          area.reload.save!
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
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/community_engine',
                layout: 'layouts/better_together/full_width_page',
                content_en: ''
              },
              {
                title: 'Subprocessors',
                slug: 'subprocessors',
                published_at: Time.zone.now,
                privacy: 'public',
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
