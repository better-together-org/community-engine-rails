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
          # DocumentationBuilder.build # TODO: Re-enable when documentation is ready

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
                show_title: false,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/better_together',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
              },
              {
                title_en: 'About the Community Engine',
                slug_en: 'better-together/community-engine',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                show_title: false,
                layout: 'layouts/better_together/full_width_page',
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/community_engine',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
              }
            ]
          )

          area = ::BetterTogether::NavigationArea.find_or_create_by!(identifier: 'better-together') do |area|
            area.name = 'Better Together'
            area.slug = 'better-together'
            area.visible = true
            area.protected = true
          end

          # Clear existing navigation items if area already existed
          area.reload.navigation_items.delete_all

          # Create Host Navigation Item
          better_together_nav_item = area.navigation_items.create!(
            identifier: 'better-together-nav',
            title_en: 'Powered with <3 by Better Together',
            slug_en: 'better-together-nav',
            position: 0,
            visible: true,
            protected: true,
            item_type: 'dropdown',
            url: '#',
            privacy: 'public'
          )

          # Add children to Better Together Navigation Item
          better_together_nav_item.create_children(better_together_pages, area)

          area.reload.save!
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
                show_title: false,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/faq',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
              },
              {
                title_en: 'Privacy Policy',
                slug_en: 'privacy-policy',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                show_title: false,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/privacy',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
              },
              {
                title_en: 'Terms of Service',
                slug_en: 'terms-of-service',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                show_title: false,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/terms_of_service',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
              },
              {
                title_en: 'Code of Conduct',
                slug_en: 'code-of-conduct',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                show_title: false,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/code_of_conduct',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
              },
              {
                title_en: 'Accessibility',
                slug_en: 'accessibility',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                show_title: false,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/accessibility',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
              },
              {
                title_en: 'Cookie Policy',
                slug_en: 'cookie-policy',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                show_title: false,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/cookie_consent',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
              },
              {
                title_en: 'Contact Us',
                slug_en: 'contact',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::RichText',
                      # rubocop:todo Lint/CopDirectiveSyntax
                      content_en: <<-HTML
                        <p>This is a default contact page for your platform. Be sure to write a real one!</p>
                      HTML
                      # rubocop:enable Lint/CopDirectiveSyntax
                    }
                  },
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/content/blocks/template/host_community_contact_details',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
              }
            ]
          )

          # Create contributor agreement pages separately for nested navigation
          contributor_agreement_pages = ::BetterTogether::Page.create!(
            [
              {
                title_en: 'Code Contributor Agreement',
                slug_en: 'code-contributor-agreement',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                show_title: false,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/code_contributor_agreement',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
              },
              {
                title_en: 'Content Contributor Agreement',
                slug_en: 'content-contributor-agreement',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                show_title: false,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/content_contributor_agreement',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
              }
            ]
          )

          # Create Platform Footer Navigation Area and its Navigation Items
          area = ::BetterTogether::NavigationArea.find_or_create_by!(identifier: 'platform-footer') do |area|
            area.name = 'Platform Footer'
            area.slug = 'platform-footer'
            area.visible = true
            area.protected = true
          end

          # Clear existing navigation items if area already existed
          area.reload.navigation_items.delete_all

          # Build navigation items for main footer pages
          area.reload.build_page_navigation_items(footer_pages)

          # Create parent "Contributor Agreements" dropdown navigation item
          # Position it after the existing footer items
          next_position = area.navigation_items.maximum(:position).to_i + 1
          contributor_agreements_parent = area.navigation_items.create!(
            title_en: 'Contributor Agreements',
            item_type: 'dropdown',
            position: next_position,
            visible: true,
            protected: true
          )

          # Build child navigation items for contributor agreements
          contributor_agreement_pages.each_with_index do |page, index|
            area.navigation_items.create!(
              title_en: page.title,
              linkable: page,
              parent: contributor_agreements_parent,
              position: index,
              item_type: 'link',
              visible: true,
              protected: true
            )
          end

          area.save!
        end
      end

      def build_header # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
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
                        <p>This is a default about page. Be sure to write a real one!</p>
                      HTML
                    }
                  }
                ]
              }
            ]
          )

          # Create Platform Header Navigation Area
          area = ::BetterTogether::NavigationArea.find_or_create_by!(identifier: 'platform-header') do |area|
            area.name = 'Platform Header'
            area.slug = 'platform-header'
            area.visible = true
            area.protected = true
          end

          # Clear existing navigation items if area already existed
          area.reload.navigation_items.delete_all

          area.build_page_navigation_items(header_pages)

          # Add non-page navigation items using route_name for URL
          non_page_nav_items = [
            {
              identifier: 'posts',
              title_en: I18n.t('navigation.header.posts', default: 'Posts'),
              slug_en: 'posts',
              position: 1,
              item_type: 'link',
              route_name: 'posts_url',
              visible: true,
              privacy: 'public',
              navigation_area: area
            },
            {
              identifier: 'events',
              title_en: I18n.t('navigation.header.events', default: 'Events'),
              slug_en: 'events',
              position: 2,
              item_type: 'link',
              route_name: 'events_url',
              visible: true,
              navigation_area: area,
              privacy: 'public'
            },
            {
              identifier: 'community-hub',
              title_en: I18n.t('navigation.header.community_hub', default: 'Community Hub'),
              slug_en: 'community-hub',
              position: 2,
              item_type: 'link',
              route_name: 'hub_url',
              visible: true,
              navigation_area: area,
              privacy: 'private',
              visibility_strategy: 'authenticated'
            },
            {
              identifier: 'exchange-hub',
              title_en: I18n.t('navigation.header.exchange_hub', default: 'Exchange Hub'),
              slug_en: 'exchange-hub',
              position: 3,
              item_type: 'link',
              route_name: 'joatu_hub_url',
              visible: true,
              navigation_area: area,
              privacy: 'private',
              visibility_strategy: 'authenticated'
            }
          ]

          non_page_nav_items.each do |attrs|
            area.navigation_items.create!(attrs)
          end

          unless area.valid?
            puts "\n=== Navigation Area Validation Errors ==="
            area.errors.full_messages.each { |msg| puts "  Area error: #{msg}" }
            area.navigation_items.each_with_index do |item, idx|
              next if item.valid?

              puts "  Item #{idx} (#{item.identifier}) errors: #{item.errors.full_messages.join(', ')}"
            end
            puts "===\n"
          end

          area.save!
        end
      end

      # rubocop:todo Metrics/MethodLength
      def build_host # rubocop:todo Metrics/MethodLength, Metrics/AbcSize, Lint/CopDirectiveSyntax, Metrics/AbcSize
        I18n.with_locale(:en) do # rubocop:todo Metrics/BlockLength
          # Create Platform Header Host Navigation Area and its Navigation Items
          area = ::BetterTogether::NavigationArea.find_or_create_by!(identifier: 'platform-host') do |area|
            area.name = 'Platform Host'
            area.slug = 'platform-host'
            area.visible = true
            area.protected = true
          end

          # Clear existing navigation items if area already existed
          area.reload.navigation_items.delete_all

          # Create Host Navigation Item
          host_nav = area.navigation_items.create!(
            identifier: 'host-nav',
            title_en: 'Host',
            slug_en: 'host-nav',
            position: 0,
            visible: true,
            protected: true,
            item_type: 'dropdown',
            url: '#',
            privacy: 'private',
            visibility_strategy: 'permission',
            permission_identifier: 'view_metrics_dashboard'
          )

          # Add children to Host Navigation Item
          host_nav_children = [
            {
              identifier: 'host-dashboard',
              title_en: 'Dashboard',
              slug_en: 'host-dashboard',
              position: 0,
              item_type: 'link',
              route_name: 'host_dashboard_url',
              privacy: 'private',
              visibility_strategy: 'permission',
              permission_identifier: 'manage_platform'
            },
            {
              identifier: 'analytics',
              title_en: 'Analytics',
              slug_en: 'analytics',
              position: 1,
              item_type: 'link',
              route_name: 'metrics_reports_url',
              icon: 'chart-line',
              privacy: 'private',
              visibility_strategy: 'permission',
              permission_identifier: 'view_metrics_dashboard'
            },
            {
              identifier: 'communities',
              title_en: 'Communities',
              slug_en: 'communities',
              position: 2,
              item_type: 'link',
              route_name: 'communities_url',
              privacy: 'private',
              visibility_strategy: 'permission',
              permission_identifier: 'manage_platform'
            },
            {
              identifier: 'navigation-areas',
              title_en: 'Navigation Areas',
              slug_en: 'navigation-areas',
              position: 3,
              item_type: 'link',
              route_name: 'navigation_areas_url',
              privacy: 'private',
              visibility_strategy: 'permission',
              permission_identifier: 'manage_platform'
            },
            {
              identifier: 'pages',
              title_en: 'Pages',
              slug_en: 'pages',
              position: 4,
              item_type: 'link',
              route_name: 'pages_url',
              privacy: 'private',
              visibility_strategy: 'permission',
              permission_identifier: 'manage_platform'
            },
            {
              identifier: 'host-posts',
              title_en: 'Posts',
              slug_en: 'host-posts',
              position: 5,
              item_type: 'link',
              route_name: 'posts_url',
              privacy: 'private',
              visibility_strategy: 'permission',
              permission_identifier: 'manage_platform'
            },
            {
              identifier: 'people',
              title_en: 'People',
              slug_en: 'people',
              position: 6,
              item_type: 'link',
              route_name: 'people_url',
              privacy: 'private',
              visibility_strategy: 'permission',
              permission_identifier: 'manage_platform'
            },
            {
              identifier: 'platforms',
              title_en: 'Platforms',
              slug_en: 'platforms',
              position: 7,
              item_type: 'link',
              route_name: 'platforms_url',
              privacy: 'private',
              visibility_strategy: 'permission',
              permission_identifier: 'manage_platform'
            },
            {
              identifier: 'roles',
              title_en: 'Roles',
              slug_en: 'roles',
              position: 8,
              item_type: 'link',
              route_name: 'roles_url',
              privacy: 'private',
              visibility_strategy: 'permission',
              permission_identifier: 'manage_platform'
            },
            {
              identifier: 'resource_permissions',
              title_en: 'Resource Permissions',
              slug_en: 'resource_permissions',
              position: 9,
              item_type: 'link',
              route_name: 'resource_permissions_url',
              privacy: 'private',
              visibility_strategy: 'permission',
              permission_identifier: 'manage_platform'
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

      # Reset and reseed navigation areas only (preserves pages)
      # Usage: BetterTogether::NavigationBuilder.reset_navigation_areas
      def reset_navigation_areas
        puts 'Resetting navigation areas...'
        delete_navigation_items
        delete_navigation_areas
        puts 'Rebuilding navigation areas...'
        I18n.with_locale(:en) do
          build_header
          build_host
          build_better_together
          build_footer
          # DocumentationBuilder.build # TODO: Re-enable when documentation is ready
        end
        puts 'Navigation areas reset complete!'
      end

      # Reset and reseed a specific navigation area
      # Usage: BetterTogether::NavigationBuilder.reset_navigation_area('platform-header')
      def reset_navigation_area(slug) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength, Lint/CopDirectiveSyntax, Metrics/MethodLength
        area = ::BetterTogether::NavigationArea.i18n.find_by(slug: slug)
        if area
          puts "Resetting navigation area: #{area.name} (#{slug})"
          # Delete items for this area
          area.navigation_items.where.not(parent_id: nil).delete_all
          area.navigation_items.where(parent_id: nil).delete_all
          area.delete
        else
          puts "Navigation area with slug '#{slug}' not found - creating it"
        end

        # Rebuild the specific area
        I18n.with_locale(:en) do
          case slug
          when 'platform-header'
            build_header
          when 'platform-host'
            build_host
          when 'better-together'
            build_better_together
          when 'platform-footer'
            build_footer
          when 'documentation'
            DocumentationBuilder.build # Available but not auto-seeded
          else
            puts "Unknown navigation area slug: #{slug}"
            return
          end
        end
        puts "Navigation area '#{slug}' reset complete!"
      end

      def create_unassociated_pages # rubocop:todo Metrics/MethodLength
        I18n.with_locale(:en) do # rubocop:todo Metrics/BlockLength
          # Create Pages not associated with a navigation area
          ::BetterTogether::Page.create!(
            [
              {
                title_en: 'Home',
                slug_en: 'home',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                layout: 'layouts/better_together/full_width_page',
                show_title: false,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/community_engine',
                      css_settings: { container_class: '' }
                    }
                  }
                ]
              },
              {
                title_en: 'Subprocessors',
                slug_en: 'subprocessors',
                published_at: Time.zone.now,
                privacy: 'public',
                protected: true,
                page_blocks_attributes: [
                  {
                    block_attributes: {
                      type: 'BetterTogether::Content::Template',
                      template_path: 'better_together/static_pages/subprocessors',
                      css_settings: { container_class: '', css_classes: 'my-4' }
                    }
                  }
                ]
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
        # Clear sidebar_nav references before deleting navigation areas
        ::BetterTogether::Page.update_all(sidebar_nav_id: nil)
        ::BetterTogether::NavigationArea.delete_all
      end

      def delete_navigation_items
        # Delete children first to satisfy FK constraints, then parents
        ::BetterTogether::NavigationItem.where.not(parent_id: nil).delete_all
        ::BetterTogether::NavigationItem.where(parent_id: nil).delete_all
      end
    end
  end
end
