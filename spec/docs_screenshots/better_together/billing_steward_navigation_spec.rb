# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_steward_navigation_spec.rb'
# The markers it targets are locked by spec/dom_contracts/billing_steward_navigation_spec.rb.
RSpec.describe 'Documentation screenshots for the billing steward menu', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let!(:host_platform) { configure_host_platform }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync lookups]) })
    Current.platform = host_platform
    BetterTogether::NavigationBuilder.build_host
  end

  after { Current.platform = nil }

  def open_host_menu
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/plans"
    find('#userNavbarDropdownMenuLink').click
    find('#host-nav-item a.dropdown-toggle').click
    expect(page).to have_css('#host-nav-item a.dropdown-item[data-identifier="billing-subscribers"]', visible: :visible, wait: 10)
    # The screenshot engine hides sticky bars; keep the open menu in the picture.
    page.execute_script(<<~JS)
      document.querySelectorAll('#host-nav-item .dropdown-menu, #userNavbarDropdownMenuLink + .dropdown-menu').forEach((menu) => {
        menu.style.setProperty('visibility', 'visible', 'important');
      });
    JS
  end

  it 'captures the host menu with the billing steward pages' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_steward_navigation',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_steward_navigation',
                  flow: 'billing_steward_navigation', source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'agreement_requirements', selector: '#host-nav-item a.dropdown-item[data-identifier="billing-agreement-requirements"]',
                   title: 'Billing pages', bullets: ['Purchase terms, subscribers, tax and more now have menu entries.'],
                   avoid_selectors: ['#host-nav-item .dropdown-menu', '#userNavbarDropdownMenuLink + .dropdown-menu'] }],
      narrative: {
        title: 'Billing steward menu',
        audience: %w[platform_organizer],
        journey_step: 'As a platform organizer, I find every billing page in the host menu without typing a URL.',
        callouts: [{ id: 'agreement_requirements', title: 'Billing pages',
                     description: 'Purchase terms, subscribers, tax registrations, promotion codes, store credit and allowances.' }],
        accessibility_notes: 'Entries are links in a labelled dropdown; they are reachable and openable from the keyboard.'
      }
    ) do
      open_host_menu
      expect(page).to have_css('#host-nav-item a.dropdown-item[data-identifier="billing-subscribers"]')
    end
  end
end
