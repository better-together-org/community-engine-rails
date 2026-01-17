# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module BetterTogether
  RSpec.describe NavigationBuilder, type: :builder do
    before do
      # Clean up existing navigation data before each test
      described_class.clear_existing
    end

    describe '.reset_navigation_areas' do
      it 'deletes all navigation items' do
        # Create some test navigation areas and items first
        area = create(:better_together_navigation_area)
        create(:better_together_navigation_item, navigation_area: area)

        described_class.reset_navigation_areas

        # After reset, should have new items from seed_data, but old ones should be gone
        expect(BetterTogether::NavigationItem.where(navigation_area: area).count).to eq(0)
      end

      it 'deletes all navigation areas' do
        # Create a test navigation area
        create(:better_together_navigation_area, name: 'Test Area', identifier: 'test-area')

        described_class.reset_navigation_areas

        # Should have exactly 4 areas (the seeded ones - documentation disabled), regardless of what was there before
        expect(BetterTogether::NavigationArea.count).to eq(4)
        # The test area should be gone
        expect(BetterTogether::NavigationArea.find_by(identifier: 'test-area')).to be_nil
      end

      it 'rebuilds all navigation areas' do
        described_class.reset_navigation_areas

        expect(BetterTogether::NavigationArea.count).to eq(4)

        # Use identifier instead of slug
        area_identifiers = BetterTogether::NavigationArea.pluck(:identifier)
        expect(area_identifiers).to contain_exactly(
          'platform-header',
          'platform-host',
          'better-together',
          'platform-footer'
          # 'documentation' - disabled for now
        )
      end

      it 'recreates navigation items' do
        described_class.reset_navigation_areas

        expect(BetterTogether::NavigationItem.count).to be > 0
      end

      it 'creates protected navigation areas' do
        described_class.reset_navigation_areas

        BetterTogether::NavigationArea.find_each do |area|
          expect(area.protected).to be true
        end
      end

      it 'creates protected navigation items' do
        described_class.reset_navigation_areas

        # Most seeded items should be protected (but not all, some may be unprotected)
        protected_items = BetterTogether::NavigationItem.where(protected: true)
        expect(protected_items.count).to be > 0
      end
    end

    describe '.reset_navigation_area' do
      context 'with valid navigation area identifier' do
        it 'works for platform-header' do
          described_class.reset_navigation_area('platform-header')

          header = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-header')
          expect(header).to be_present
          expect(header.navigation_items.count).to be > 0
        end

        it 'works for platform-host' do
          described_class.reset_navigation_area('platform-host')

          host = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-host')
          expect(host).to be_present
          expect(host.navigation_items.count).to be > 0
        end

        it 'works for better-together' do
          described_class.reset_navigation_area('better-together')

          bt = BetterTogether::NavigationArea.i18n.find_by(slug: 'better-together')
          expect(bt).to be_present
          expect(bt.navigation_items.count).to be > 0
        end

        it 'works for platform-footer' do
          described_class.reset_navigation_area('platform-footer')

          footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
          expect(footer).to be_present
          expect(footer.navigation_items.count).to be > 0
        end

        it 'works for documentation' do
          skip 'Documentation builder is disabled from auto-seeding (WIP)'

          # Documentation builder available but not auto-seeded
          described_class.reset_navigation_area('documentation')

          docs_area = BetterTogether::NavigationArea.i18n.find_by(slug: 'documentation')
          expect(docs_area).to be_present
          expect(docs_area.navigation_items.count).to be > 0
        end

        it 'deletes old navigation items for that area' do
          # Create the footer area first
          described_class.reset_navigation_area('platform-footer')

          # Reset it again - the area gets deleted and recreated
          described_class.reset_navigation_area('platform-footer')

          # Should have the recreated footer with navigation items
          footer_area = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
          expect(footer_area).to be_present
          expect(footer_area.navigation_items.count).to be > 0
        end

        it 'creates new navigation items for that area' do
          described_class.reset_navigation_area('platform-footer')

          footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
          expect(footer.navigation_items.count).to be > 0
        end

        it 'resets the specified area' do
          # Setup initial state
          described_class.reset_navigation_areas

          footer_area = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
          initial_name = footer_area.name

          # Reset just the footer
          described_class.reset_navigation_area('platform-footer')

          footer_area = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
          expect(footer_area.name).to eq(initial_name)
        end

        it 'preserves other navigation areas' do
          # Setup initial state
          described_class.reset_navigation_areas

          initial_identifiers = BetterTogether::NavigationArea.pluck(:identifier).sort

          # Reset just the footer
          described_class.reset_navigation_area('platform-footer')

          # Should still have all 5 areas
          final_identifiers = BetterTogether::NavigationArea.pluck(:identifier).sort
          expect(final_identifiers).to eq(initial_identifiers)
        end
      end

      context 'with invalid navigation area identifier' do
        it 'does not raise an error' do
          expect do
            described_class.reset_navigation_area('invalid-slug')
          end.not_to raise_error
        end

        it 'does not affect existing areas' do
          described_class.reset_navigation_areas
          initial_count = BetterTogether::NavigationArea.count

          described_class.reset_navigation_area('invalid-slug')

          expect(BetterTogether::NavigationArea.count).to eq(initial_count)
        end
      end

      context 'with nil identifier' do
        it 'does not raise an error' do
          expect do
            described_class.reset_navigation_area(nil)
          end.not_to raise_error
        end
      end
    end

    describe 'navigation item relationships' do
      before do
        described_class.reset_navigation_areas
      end

      it 'creates parent-child relationships for contributor agreements' do
        footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')

        # Find the "Contributor Agreements" parent item
        contributor_agreements_item = footer.navigation_items.find_by(item_type: 'dropdown')

        expect(contributor_agreements_item).to be_present
        expect(contributor_agreements_item.children.count).to eq(2)
      end

      it 'includes both contributor agreement pages as children' do
        footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
        contributor_agreements_item = footer.navigation_items.find_by(item_type: 'dropdown')

        child_slugs = contributor_agreements_item.children.map { |child| child.linkable&.slug }.compact
        # Check that both agreement types are present (slug may have FriendlyId suffix after reset)
        expect(child_slugs.any? { |slug| slug.start_with?('code-contributor-agreement') }).to be true
        expect(child_slugs.any? { |slug| slug.start_with?('content-contributor-agreement') }).to be true
      end

      it 'preserves nested structure after reset' do
        # Get initial structure
        footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
        initial_parent_count = footer.navigation_items.where(parent_id: nil).count
        initial_child_count = footer.navigation_items.where.not(parent_id: nil).count

        # Reset the footer
        described_class.reset_navigation_area('platform-footer')

        # Check structure is preserved
        footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
        expect(footer.navigation_items.where(parent_id: nil).count).to eq(initial_parent_count)
        expect(footer.navigation_items.where.not(parent_id: nil).count).to eq(initial_child_count)
      end

      describe '.seed_data' do
        it 'creates all navigation areas and items' do
          # Ensure clean slate before seeding
          described_class.clear_existing
          
          expect { described_class.seed_data }
            .to change(NavigationArea, :count).by(4)
            .and change(NavigationItem, :count).by_at_least(1)
            .and change(Page, :count).by_at_least(1)
        end
      end

      describe '.build_header' do
        it 'creates Platform Header navigation area' do
          described_class.build_header

          area = NavigationArea.find_by(identifier: 'platform-header')
          expect(area).to be_present
          expect(area.name).to eq('Platform Header')
          expect(area.visible).to be true
          expect(area.protected).to be true
        end

        it 'creates About page' do
          described_class.build_header

          page = Page.find_by(identifier: 'about')
          expect(page).to be_present
          expect(page.title_en).to eq('About')
          expect(page.privacy).to eq('public')
          expect(page.protected).to be true
        end

        it 'creates posts navigation item with correct attributes' do
          described_class.build_header

          area = NavigationArea.find_by(identifier: 'platform-header')
          posts_item = area.navigation_items.find_by(identifier: 'posts')

          expect(posts_item).to be_present
          expect(posts_item.title_en).to eq('Posts')
          expect(posts_item.route_name).to eq('posts_url')
          expect(posts_item.position).to eq(1)
          expect(posts_item.item_type).to eq('link')
          expect(posts_item.visible).to be true
          expect(posts_item.privacy).to eq('public')
        end

        it 'creates events navigation item' do
          described_class.build_header

          area = NavigationArea.find_by(identifier: 'platform-header')
          events_item = area.navigation_items.find_by(identifier: 'events')

          expect(events_item).to be_present
          expect(events_item.title_en).to eq('Events')
          expect(events_item.route_name).to eq('events_url')
          expect(events_item.position).to eq(2)
          expect(events_item.visible).to be true
        end

        it 'creates exchange hub navigation item' do
          described_class.build_header

          area = NavigationArea.find_by(identifier: 'platform-header')
          exchange_item = area.navigation_items.find_by(identifier: 'exchange-hub')

          expect(exchange_item).to be_present
          expect(exchange_item.title_en).to eq('Exchange Hub')
          expect(exchange_item.route_name).to eq('joatu_hub_url')
          expect(exchange_item.position).to eq(3)
          expect(exchange_item.visible).to be true
        end
      end

      describe '.build_host' do
        it 'creates Platform Host navigation area' do
          described_class.build_host

          area = NavigationArea.find_by(identifier: 'platform-host')
          expect(area).to be_present
          expect(area.name).to eq('Platform Host')
          expect(area.visible).to be true
          expect(area.protected).to be true
        end

        it 'creates host dropdown navigation item' do
          described_class.build_host

          area = NavigationArea.find_by(identifier: 'platform-host')
          host_nav = area.navigation_items.find_by(identifier: 'host-nav')

          expect(host_nav).to be_present
          expect(host_nav.title_en).to eq('Host')
          expect(host_nav.item_type).to eq('dropdown')
          expect(host_nav.visible).to be true
          expect(host_nav.protected).to be true
          expect(host_nav.privacy).to eq('private')
          expect(host_nav.visibility_strategy).to eq('permission')
          expect(host_nav.permission_identifier).to eq('view_metrics_dashboard')
        end

        it 'creates posts navigation item in host dropdown with correct attributes' do
          described_class.build_host

          area = NavigationArea.find_by(identifier: 'platform-host')
          host_nav = area.navigation_items.find_by(identifier: 'host-nav')
          posts_item = host_nav.children.find_by(identifier: 'host-posts')

          expect(posts_item).to be_present
          expect(posts_item.title_en).to eq('Posts')
          expect(posts_item.route_name).to eq('posts_url')
          expect(posts_item.position).to eq(5)
          expect(posts_item.item_type).to eq('link')
          expect(posts_item.visible).to be true
          expect(posts_item.protected).to be true
          expect(posts_item.privacy).to eq('private')
          expect(posts_item.visibility_strategy).to eq('permission')
          expect(posts_item.permission_identifier).to eq('manage_platform')
          expect(posts_item.navigation_area).to eq(area)
        end

        it 'creates all host dropdown children in correct order' do
          described_class.build_host

          area = NavigationArea.find_by(identifier: 'platform-host')
          host_nav = area.navigation_items.find_by(identifier: 'host-nav')
          children = host_nav.children.order(:position)

          expect(children.count).to eq(10)
          expect(children.map(&:identifier)).to eq(%w[
                                                     host-dashboard
                                                     analytics
                                                     communities
                                                     navigation-areas
                                                     pages
                                                     host-posts
                                                     people
                                                     platforms
                                                     roles
                                                     resource_permissions
                                                   ])
        end

        it 'creates dashboard navigation item' do
          described_class.build_host

          area = NavigationArea.find_by(identifier: 'platform-host')
          host_nav = area.navigation_items.find_by(identifier: 'host-nav')
          dashboard_item = host_nav.children.find_by(identifier: 'host-dashboard')

          expect(dashboard_item).to be_present
          expect(dashboard_item.title_en).to eq('Dashboard')
          expect(dashboard_item.route_name).to eq('host_dashboard_url')
          expect(dashboard_item.position).to eq(0)
          expect(dashboard_item.privacy).to eq('private')
          expect(dashboard_item.permission_identifier).to eq('manage_platform')
        end

        it 'creates analytics navigation item' do
          described_class.build_host

          area = NavigationArea.find_by(identifier: 'platform-host')
          host_nav = area.navigation_items.find_by(identifier: 'host-nav')
          analytics_item = host_nav.children.find_by(identifier: 'analytics')

          expect(analytics_item).to be_present
          expect(analytics_item.title_en).to eq('Analytics')
          expect(analytics_item.route_name).to eq('metrics_reports_url')
          expect(analytics_item.position).to eq(1)
          expect(analytics_item.icon).to eq('chart-line')
          expect(analytics_item.permission_identifier).to eq('view_metrics_dashboard')
        end

        it 'sets all children as visible and protected' do
          described_class.build_host

          area = NavigationArea.find_by(identifier: 'platform-host')
          host_nav = area.navigation_items.find_by(identifier: 'host-nav')
          children = host_nav.children

          expect(children.all?(&:visible)).to be true
          expect(children.all?(&:protected)).to be true
        end
      end

      describe '.build_better_together' do
        it 'creates Better Together navigation area' do
          described_class.build_better_together

          area = NavigationArea.find_by(identifier: 'better-together')
          expect(area).to be_present
          expect(area.name).to eq('Better Together')
          expect(area.visible).to be true
          expect(area.protected).to be true
        end

        it 'creates Better Together pages' do
          described_class.build_better_together

          what_is_page = Page.find_by(identifier: 'better-together')
          engine_page = Page.find_by(identifier: 'better-together-community-engine')

          expect(what_is_page).to be_present
          expect(what_is_page.title_en).to eq('What is Better Together?')
          expect(engine_page).to be_present
          expect(engine_page.title_en).to eq('About the Community Engine')
        end

        it 'creates Better Together navigation item' do
          described_class.build_better_together

          area = NavigationArea.find_by(identifier: 'better-together')
          nav_item = area.navigation_items.find_by(identifier: 'better-together-nav')

          expect(nav_item).to be_present
          expect(nav_item.title_en).to eq('Powered with <3 by Better Together')
          expect(nav_item.item_type).to eq('dropdown')
          expect(nav_item.visible).to be true
          expect(nav_item.protected).to be true
        end
      end

      describe '.build_footer' do
        it 'creates Platform Footer navigation area' do
          described_class.build_footer

          area = NavigationArea.find_by(identifier: 'platform-footer')
          expect(area).to be_present
          expect(area.name).to eq('Platform Footer')
          expect(area.visible).to be true
          expect(area.protected).to be true
        end

        it 'creates footer pages' do
          described_class.build_footer

          faq_page = Page.find_by(identifier: 'faq')
          privacy_page = Page.find_by(identifier: 'privacy-policy')
          terms_page = Page.find_by(identifier: 'terms-of-service')
          code_page = Page.find_by(identifier: 'code-of-conduct')
          accessibility_page = Page.find_by(identifier: 'accessibility')
          contact_page = Page.find_by(identifier: 'contact')

          expect(faq_page).to be_present
          expect(privacy_page).to be_present
          expect(terms_page).to be_present
          expect(code_page).to be_present
          expect(accessibility_page).to be_present
          expect(contact_page).to be_present
        end
      end

      describe '.create_unassociated_pages' do
        it 'creates Home page' do
          described_class.create_unassociated_pages

          home_page = Page.find_by(identifier: 'home')
          expect(home_page).to be_present
          expect(home_page.title_en).to eq('Home')
          expect(home_page.privacy).to eq('public')
          expect(home_page.protected).to be true
        end

        it 'creates Subprocessors page' do
          described_class.create_unassociated_pages

          subprocessors_page = Page.find_by(identifier: 'subprocessors')
          expect(subprocessors_page).to be_present
          expect(subprocessors_page.title_en).to eq('Subprocessors')
          expect(subprocessors_page.privacy).to eq('public')
          expect(subprocessors_page.protected).to be true
        end
      end

      describe '.clear_existing' do
        before do
          described_class.seed_data
        end

        it 'deletes all navigation data' do
          expect { described_class.clear_existing }
            .to change(NavigationArea, :count).to(0)
            .and change(NavigationItem, :count).to(0)
            .and change(Page, :count).to(0)
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
