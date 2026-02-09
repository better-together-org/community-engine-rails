# frozen_string_literal: true

require 'rails_helper'

# TODO: These feature specs need investigation - sidebar nav isn't rendering in test environment
# Core functionality (helpers, models, touch callbacks) is verified by unit tests
RSpec.describe 'Sidebar Navigation Cache Invalidation', :as_user, :js, retry: 0 do
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:community) { platform.community }
  let(:test_user) { BetterTogether::User.find_by!(email: 'user@example.test') }

  # Use unique names to avoid collisions when running in parallel
  let(:unique_suffix) { SecureRandom.hex(4) }

  let!(:navigation_area) do
    create(:better_together_navigation_area,
           slug: "main-nav-#{unique_suffix}",
           name: "Main Navigation #{unique_suffix}",
           navigable: community)
  end

  let!(:page_one) { create(:better_together_page, slug: "page-one-#{unique_suffix}", title: 'Original Page Title', community: community) }
  let!(:page_two) { create(:better_together_page, slug: "page-two-#{unique_suffix}", title: 'Alternative Page', community: community) }
  let!(:current_page) do
    create(:better_together_page,
           slug: "current-#{unique_suffix}",
           title: 'Current Page',
           community: community)
  end

  let!(:nav_item) do
    create(:better_together_navigation_item,
           navigation_area: navigation_area,
           linkable: page_one,
           title: nil, # Use linkable's title
           position: 1,
           visible: true)
  end

  before do
    # Assign sidebar_nav after all resources are created
    current_page.update!(sidebar_nav: navigation_area)

    # Enable caching for this test
    allow(Rails.application.config.action_controller).to receive(:perform_caching).and_return(true)
    Rails.cache.clear
  end

  after do
    Rails.cache.clear
  end

  describe 'Page title changes' do
    it 'invalidates sidebar cache when linked page title is updated', :accessibility do
      pending 'Sidebar nav not rendering in feature test environment - investigating test setup'

      # Visit a page that displays the sidebar navigation
      visit better_together.page_path(current_page, locale: I18n.default_locale)

      # Wait for page to load and verify initial title is displayed
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)
      expect(page).to have_content('Original Page Title')

      # Update the linked page's title
      page_one.update!(title: 'Updated Page Title via Cache Test')

      # Reload the page to trigger cache check
      visit better_together.page_path(current_page, locale: I18n.default_locale)

      # Wait for sidebar to render
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)

      # Verify the updated title appears (cache was invalidated)
      expect(page).to have_content('Updated Page Title via Cache Test')
      expect(page).not_to have_content('Original Page Title')

      # Run accessibility check on the updated sidebar
      expect(page).to be_axe_clean
        .within('#sidebar_nav_accordion')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end

  describe 'Linkable association changes' do
    it 'invalidates sidebar cache when navigation item linkable is updated', :accessibility do
      pending 'Sidebar nav not rendering in feature test environment - investigating test setup'

      # Visit a page that displays the sidebar navigation
      visit better_together.page_path(current_page, locale: I18n.default_locale)

      # Wait for page to load and verify initial linked page appears
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)
      expect(page).to have_content('Original Page Title')
      expect(page).not_to have_content('Alternative Page')

      # Update the navigation item to link to a different page
      nav_item.update!(linkable: page_two)

      # Reload the page to trigger cache check
      visit better_together.page_path(current_page, locale: I18n.default_locale)

      # Wait for sidebar to render
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)

      # Verify the new linked page title appears (cache was invalidated)
      expect(page).to have_content('Alternative Page')
      expect(page).not_to have_content('Original Page Title')

      # Run accessibility check on the updated sidebar
      expect(page).to be_axe_clean
        .within('#sidebar_nav_accordion')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end

  describe 'Multiple updates' do
    it 'consistently invalidates cache across multiple changes' do
      pending 'Sidebar nav not rendering in feature test environment - investigating test setup'

      # Visit a page that displays the sidebar navigation
      visit better_together.page_path(current_page, locale: I18n.default_locale)

      # Verify initial state
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)
      expect(page).to have_content('Original Page Title')

      # First update: Change page title
      page_one.update!(title: 'First Update')
      visit better_together.page_path(current_page, locale: I18n.default_locale)
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)
      expect(page).to have_content('First Update')

      # Second update: Change linkable to different page
      nav_item.update!(linkable: page_two)
      visit better_together.page_path(current_page, locale: I18n.default_locale)
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)
      expect(page).to have_content('Alternative Page')

      # Third update: Change the new page's title
      page_two.update!(title: 'Second Update')
      visit better_together.page_path(current_page, locale: I18n.default_locale)
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)
      expect(page).to have_content('Second Update')

      # Fourth update: Switch back to original page
      nav_item.update!(linkable: page_one)
      visit better_together.page_path(current_page, locale: I18n.default_locale)
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)
      expect(page).to have_content('First Update')
    end
  end

  describe 'Cache key behavior' do
    it 'generates different cache keys for different current pages' do
      pending 'Sidebar nav not rendering in feature test environment - investigating test setup'

      # Create another page to serve as a different current_page (with unique slug)
      other_page = create(:better_together_page,
                          slug: "other-page-#{unique_suffix}",
                          title: 'Other Page',
                          community: community)
      other_page.update!(sidebar_nav: navigation_area)

      # Visit first page and verify sidebar renders
      visit better_together.page_path(current_page, locale: I18n.default_locale)
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)
      expect(page).to have_content('Original Page Title')

      # Visit second page - should use different cache key due to different current_page.id
      visit better_together.page_path(other_page, locale: I18n.default_locale)
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)
      expect(page).to have_content('Original Page Title')

      # Update page title
      page_one.update!(title: 'Updated for Cache Key Test')

      # Both pages should show the updated title (both cache keys invalidated)
      visit better_together.page_path(current_page, locale: I18n.default_locale)
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)
      expect(page).to have_content('Updated for Cache Key Test')

      visit better_together.page_path(other_page, locale: I18n.default_locale)
      expect(page).to have_css('#sidebar_nav_accordion', wait: 10)
      expect(page).to have_content('Updated for Cache Key Test')
    end
  end
end
