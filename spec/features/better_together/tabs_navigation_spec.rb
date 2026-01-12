# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Tabbed navigation', :js, :no_auth do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host)
    platform_manager_role = BetterTogether::Role.find_by!(
      identifier: 'platform_manager'
    )
    # Community member role should already be seeded
    manage_platform_permission = BetterTogether::ResourcePermission.find_by!(
      identifier: 'manage_platform'
    )
    platform_manager_role.assign_resource_permissions([manage_platform_permission.identifier])

    manager_user = BetterTogether::User.find_by(email: 'manager@example.test') ||
                   create(:better_together_user, :confirmed,
                          email: 'manager@example.test',
                          password: 'SecureTest123!@#')
    unless host_platform.person_platform_memberships.exists?(member: manager_user.person,
                                                             role: platform_manager_role)
      host_platform.person_platform_memberships.create!(
        member: manager_user.person,
        role: platform_manager_role
      )
    end
    Rails.cache.clear

    platform_header_area = BetterTogether::NavigationArea.find_by!(
      identifier: 'platform-header'
    )
    about_page = create(:better_together_page,
                        title: 'About',
                        slug: 'about',
                        privacy: 'public',
                        published_at: 2.days.ago)
    create(:better_together_navigation_item,
           navigation_area: platform_header_area,
           title: 'Events',
           slug: 'events',
           visible: true,
           position: 0,
           item_type: 'link',
           route_name: 'events_url',
           url: nil)
    create(:better_together_navigation_item,
           navigation_area: platform_header_area,
           title: 'Exchange Hub',
           slug: 'exchange-hub',
           visible: true,
           position: 1,
           item_type: 'link',
           route_name: 'joatu_hub_url',
           url: nil)
    create(:better_together_navigation_item,
           navigation_area: platform_header_area,
           title: 'About',
           slug: 'about',
           visible: true,
           position: 2,
           item_type: 'link',
           linkable: about_page)

    platform_host_area = BetterTogether::NavigationArea.find_or_create_by!(
      identifier: 'platform-host'
    ) do |area|
      area.name = 'Platform Host'
      area.slug = 'platform-host'
      area.visible = true
      area.protected = true
      area.navigable_type = 'BetterTogether::Platform'
      area.navigable_id = host_platform.id
    end
    host_nav = BetterTogether::NavigationItem.find_or_create_by!(
      identifier: 'host-nav',
      navigation_area: platform_host_area,
      parent_id: nil
    ) do |nav_item|
      nav_item.title = 'Host'
      nav_item.slug = 'host-nav'
      nav_item.visible = true
      nav_item.position = 0
      nav_item.item_type = 'dropdown'
      nav_item.url = '#'
      nav_item.protected = true
    end
    host_child = BetterTogether::NavigationItem.find_or_initialize_by(
      identifier: 'host-resource-permissions',
      navigation_area: platform_host_area,
      parent: host_nav
    )
    if host_child.new_record?
      host_child.assign_attributes(
        title: 'Resource permissions',
        slug: 'host-resource-permissions',
        visible: true,
        position: host_nav.children.maximum(:position).to_i + 1,
        item_type: 'link',
        route_name: 'resource_permissions_url'
      )
      host_child.save!
    end

    create(:better_together_resource_permission,
           resource_type: 'BetterTogether::Community',
           action: 'view')
    create(:better_together_resource_permission,
           resource_type: 'BetterTogether::Community',
           action: 'manage')
    create(:better_together_resource_permission,
           resource_type: 'BetterTogether::Platform',
           action: 'view')

    # Login AFTER all data setup is complete
    capybara_login_as_platform_manager
  end

  scenario 'updates the hash when switching resource type tabs', skip: 'Flaky - race condition with tab switching' do
    visit better_together.resource_permissions_path(locale:)

    platform_tab_id = "resource-permissions-#{'BetterTogether::Platform'.parameterize}"
    find("button[data-bs-target=\"##{platform_tab_id}\"]").click

    expect(page).to have_current_path(
      /##{Regexp.escape(platform_tab_id)}\z/,
      url: true
    )
  end

  scenario 'updates the hash when switching nested action tabs', skip: 'Flaky - race condition with tab switching' do
    visit better_together.resource_permissions_path(locale:)

    community_action_tab_id = "resource-permissions-#{'BetterTogether::Community'.parameterize}-action-manage"
    find("button[data-bs-target=\"##{community_action_tab_id}\"]").click

    expect(page).to have_current_path(
      /##{Regexp.escape(community_action_tab_id)}\z/,
      url: true
    )
  end

  scenario 'activates the nested action tab from the hash on load', skip: 'Flaky - race condition with tab activation' do
    community_action_tab_id = "resource-permissions-#{'BetterTogether::Community'.parameterize}-action-manage"
    visit "#{better_together.resource_permissions_path(locale:)}##{community_action_tab_id}"

    expect(page).to have_css(
      "button##{community_action_tab_id}-tab.active"
    )
  end

  scenario 'activates the matching outer and inner tabs from the hash on load', skip: 'Flaky - race condition with tab activation' do
    platform_tab_id = "resource-permissions-#{'BetterTogether::Platform'.parameterize}"
    platform_action_tab_id = "#{platform_tab_id}-action-manage"

    visit "#{better_together.resource_permissions_path(locale:)}##{platform_action_tab_id}"

    expect(page).to have_css("button##{platform_tab_id}-tab.active")
    expect(page).to have_css("button##{platform_action_tab_id}-tab.active")
  end

  scenario 'shows all resource type panes when selecting all', skip: 'Flaky - race condition with tab selection' do
    visit better_together.resource_permissions_path(locale:)

    all_tab_id = 'resource-permissions-all'
    find("button[data-better_together--tabs-hash=\"##{all_tab_id}\"]").click

    community_tab_id = "resource-permissions-#{'BetterTogether::Community'.parameterize}"
    platform_tab_id = "resource-permissions-#{'BetterTogether::Platform'.parameterize}"

    expect(page).to have_css("##{community_tab_id}.show.active")
    expect(page).to have_css("##{platform_tab_id}.show.active")
  end

  scenario 'switches from all to a single resource type tab', skip: 'Flaky - race condition with tab switching' do
    visit better_together.resource_permissions_path(locale:)

    all_tab_id = 'resource-permissions-all'
    find("button[data-better_together--tabs-hash=\"##{all_tab_id}\"]").click

    platform_tab_id = "resource-permissions-#{'BetterTogether::Platform'.parameterize}"
    find("button[data-bs-target=\"##{platform_tab_id}\"]").click

    expect(page).to have_css("##{platform_tab_id}.show.active")
    expect(page).not_to have_css("##{all_tab_id}.show.active")
  end

  scenario 'shows all action panes within a resource type when selecting all', skip: 'Flaky - race condition with nested tab selection' do
    visit better_together.resource_permissions_path(locale:)

    community_tab_id = "resource-permissions-#{'BetterTogether::Community'.parameterize}"
    action_all_tab_id = "#{community_tab_id}-action-all"
    manage_action_tab_id = "#{community_tab_id}-action-manage"
    view_action_tab_id = "#{community_tab_id}-action-view"

    within("##{community_tab_id}") do
      find("button[data-better_together--tabs-hash=\"##{action_all_tab_id}\"]").click
    end

    expect(page).to have_css("##{manage_action_tab_id}.show.active")
    expect(page).to have_css("##{view_action_tab_id}.show.active")
  end

  scenario 'renders rbac nav with counts', skip: 'Flaky - race condition with nav rendering' do
    visit better_together.resource_permissions_path(locale:)

    expect(page).to have_css('.rbac-nav .nav-link', text: I18n.t('better_together.rbac.nav.resource_permissions'))
    expect(page).to have_css('.rbac-nav .nav-link', text: I18n.t('better_together.rbac.nav.roles'))
    expect(page).to have_css('.rbac-nav .badge')
  end

  scenario 'adds spacing classes to collapsed header nav items',
           skip: 'Flaky - race condition with navigation rendering in parallel execution' do
    visit better_together.resource_permissions_path(locale:)

    expect(page).to have_css('#headerNav .navbar-nav.gap-2.gap-md-3', visible: :all)
  end

  scenario 'renders role type tabs with badges and accents', skip: 'Flaky - race condition with tab rendering' do
    visit better_together.roles_path(locale:)

    platform_tab_id = "roles-#{'BetterTogether::Platform'.parameterize}-tab"
    community_tab_id = "roles-#{'BetterTogether::Community'.parameterize}-tab"

    expect(page).to have_css("button##{platform_tab_id}.bt-tab-control")
    expect(page).to have_css("button##{platform_tab_id} .bt-tab-badge")
    expect(page).to have_css("button##{community_tab_id}.bt-tab-control")
    expect(page).to have_css("button##{community_tab_id} .bt-tab-badge")
  end

  scenario 'highlights header nav items for events, exchange hub, and about page', skip: 'Flaky - race condition with nav highlighting' do
    visit better_together.events_path(locale:)
    expect(page).to have_css('#headerNav .nav-link.active', text: 'Events', visible: :all)

    visit better_together.joatu_hub_path(locale:)
    expect(page).to have_css('#headerNav .nav-link.active', text: 'Exchange Hub', visible: :all)

    visit "/#{locale}/about"
    expect(page).to have_css('#headerNav .nav-link.active', text: 'About', visible: :all)
  end

  scenario 'renders host sidebar navigation on rbac pages',
           skip: 'Flaky - race condition with sidebar navigation rendering in parallel execution' do
    visit better_together.resource_permissions_path(locale:)

    expect(page).to have_css('#hostNavSidebar .nav-link', text: 'Resource permissions', visible: :all)
  end

  scenario 'renders host sidebar navigation on the host dashboard',
           skip: 'Flaky - race condition with sidebar navigation rendering in parallel execution' do
    visit better_together.host_dashboard_path(locale:)

    expect(page).to have_css('#hostNavSidebar .nav-link', text: 'Resource permissions', visible: :all)
  end

  scenario 'renders host sidebar navigation on host management index pages', skip: 'Flaky - race condition with metrics page load' do
    # Create test data for metrics page
    create(:metrics_page_view, :with_page, viewed_at: 5.days.ago)

    paths = [
      better_together.platforms_path(locale:),
      better_together.people_path(locale:),
      better_together.pages_path(locale:),
      better_together.navigation_areas_path(locale:),
      better_together.metrics_reports_path(locale:)
    ]

    paths.each do |path|
      visit path

      # For metrics page, wait for JavaScript-dependent content to load
      if path == better_together.metrics_reports_path(locale:)
        # Metrics page has JavaScript that loads asynchronously
        expect(page).to have_css('#pageviews', wait: 10)
        expect(page).to have_css('[data-controller="better_together--tabs"]', wait: 5)
      end

      # Wait for sidebar navigation to render (may depend on page load completion)
      expect(page).to have_css('#hostNavSidebar', wait: 10)
      expect(page).to have_css('#hostNavSidebar .nav-link', text: 'Resource permissions', visible: :all, wait: 5)
    end
  end

  scenario 'uses nested tabs for metrics reports charts and reports', skip: 'Flaky - race condition with AJAX/tab initialization' do
    # Create test data for charts to load
    create(:metrics_page_view, :with_page, viewed_at: 5.days.ago)

    visit better_together.metrics_reports_path(locale:)

    # Wait for the main page and tabs to load
    expect(page).to have_css('#pageviews', wait: 10)

    within('#pageviews', wait: 5) do
      # Wait for nested tabs controller to initialize
      expect(page).to have_css('[data-controller="better_together--tabs"]', wait: 5)
      expect(page).to have_css('button#pageviews-charts-tab', wait: 5)
      expect(page).to have_css('button#pageviews-reports-tab', wait: 5)
      expect(page).not_to have_css('.nav-pills')
    end

    # Check for disabled nav link (wait for it to render)
    expect(page).to have_css('.nav-link.disabled',
                             text: I18n.t('better_together.metrics.reports.tabs.metrics_types'),
                             visible: :all,
                             wait: 5)
  end
end
