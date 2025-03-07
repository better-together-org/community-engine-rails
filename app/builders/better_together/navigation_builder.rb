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

      # rubocop:todo Metrics/AbcSize
      def build_better_together # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
        I18n.with_locale(:en) do # rubocop:todo Metrics/BlockLength
          # Create Better Together Nav Area
          better_together_pages = ::BetterTogether::Page.create!(
            [
              {
                title_en: 'What is Better Together?',
                slug_en: 'better-together',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/better_together'
              },
              {
                title_en: 'About the Community Engine',
                slug_en: 'better-together/community-engine',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/community_engine',
                layout: 'layouts/better_together/full_width_page'
              }
            ]
          )

          area = ::BetterTogether::NavigationArea.create! do |area| # rubocop:todo Lint/ShadowingOuterLocalVariable
            area.name = 'Better Together'
            area.slug = 'better-together'
            area.visible = true
            area.protected = true
          end

          # Create Host Navigation Item
          better_together_nav_item = area.navigation_items.create!(
            title_en: 'Powered with <3 by Better Together',
            slug_en: 'better-together-nav',
            position: 0,
            visible: true,
            protected: true,
            item_type: 'dropdown',
            url: '#'
          )

          # Add children to Better Together Navigation Item
          better_together_nav_item.create_children(better_together_pages, area.reload)

          area.save!
        end
      end
      # rubocop:enable Metrics/AbcSize

      def build_footer # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
        I18n.with_locale(:en) do # rubocop:todo Metrics/BlockLength
          # Create Platform Footer Pages
          footer_pages = ::BetterTogether::Page.create!(
            [
              {
                title_en: 'FAQ',
                slug_en: 'faq',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/faq'
              },
              {
                title_en: 'Privacy Policy',
                slug_en: 'privacy-policy',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/privacy'
              },
              {
                title_en: 'Terms of Service',
                slug_en: 'terms-of-service',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/terms_of_service'
              },
              {
                title_en: 'Code of Conduct',
                slug_en: 'code-of-conduct',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/code_of_conduct'
              },
              {
                title_en: 'Accessibility',
                slug_en: 'accessibility',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/accessibility'
              },
              {
                title_en: 'Contact',
                slug_en: 'contact',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::RichText',
                      content_en: <<-HTML
                        <h1 class="page-header mb-3">Contact Us</h1>
                        <p>This is a default contact page for your platform. Be sure to write a real one!</p>
                      HTML
                    }
                  }
                ]
              }
            ]
          )

          # Create Platform Footer Navigation Area and its Navigation Items
          area = ::BetterTogether::NavigationArea.create! do |area| # rubocop:todo Lint/ShadowingOuterLocalVariable
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
        I18n.with_locale(:en) do # rubocop:todo Metrics/BlockLength
          # Create platform header pages
          header_pages = ::BetterTogether::Page.create(
            [
              {
                title_en: 'About',
                slug_en: 'about',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::RichText',
                      content_en: <<-HTML
                        <h1 class="page-header mb-3">About</h1>
                        <p>This is a default about page. Be sure to write a real one!</p>
                      HTML
                    }
                  }
                ]
              }
            ]
          )

          # Create Platform Header Navigation Area
          area = ::BetterTogether::NavigationArea.create! do |area| # rubocop:todo Lint/ShadowingOuterLocalVariable
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
          area = ::BetterTogether::NavigationArea.create! do |area| # rubocop:todo Lint/ShadowingOuterLocalVariable
            area.name = 'Platform Host'
            area.slug = 'platform-host'
            area.visible = true
            area.protected = true
          end

          # byebug
          # Create Host Navigation Item
          host_nav = area.navigation_items.create!(
            title_en: 'Host',
            slug_en: 'host-nav',
            position: 0,
            visible: true,
            protected: true,
            item_type: 'dropdown',
            url: '#'
          )

          # Add children to Host Navigation Item
          host_nav_children = [
            {
              title_en: 'Dashboard',
              slug_en: 'host-dashboard',
              position: 0,
              item_type: 'link',
              route_name: 'host_dashboard_path'
            },
            {
              title_en: 'Communities',
              slug_en: 'communities',
              position: 1,
              item_type: 'link',
              route_name: 'communities_path'
            },
            {
              title_en: 'Navigation Areas',
              slug_en: 'navigation-areas',
              position: 2,
              item_type: 'link',
              route_name: 'navigation_areas_path'
            },
            {
              title_en: 'Pages',
              slug_en: 'pages',
              position: 3,
              item_type: 'link',
              route_name: 'pages_path'
            },
            {
              title_en: 'People',
              slug_en: 'people',
              position: 4,
              item_type: 'link',
              route_name: 'people_path'
            },
            {
              title_en: 'Platforms',
              slug_en: 'platforms',
              position: 5,
              item_type: 'link',
              route_name: 'platforms_path'
            },
            {
              title_en: 'Roles',
              slug_en: 'roles',
              position: 6,
              item_type: 'link',
              route_name: 'roles_path'
            },
            {
              title_en: 'Resource Permissions',
              slug_en: 'resource_permissions',
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
                title_en: 'Home',
                slug_en: 'home',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/community_engine',
                layout: 'layouts/better_together/full_width_page'
              },
              {
                title_en: 'Subprocessors',
                slug_en: 'subprocessors',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                template: 'better_together/static_pages/subprocessors'
              }
            ]
          )
        end
      end

      def delete_pages
        ::BetterTogether::Content::PageBlock.delete_all
        ::BetterTogether::Content::Block.delete_all
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
