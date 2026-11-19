# frozen_string_literal: true

require 'rails_helper'

# The billing entries in the host menu: reachable by keyboard, open the page they name, and
# free of axe violations. The menu is built for the signed-in steward only while billing is on.
RSpec.describe 'Billing steward navigation', :accessibility, :js, :no_auth, :skip_host_setup, retry: 0 do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let!(:host_platform) { configure_host_platform }
  let(:entry) { '#host-nav-item a.dropdown-item[data-identifier="billing-subscribers"]' }

  before do
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync lookups]) })
    Current.platform = host_platform
    BetterTogether::NavigationBuilder.build_host
    Rails.cache.clear
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/plans"
  end

  after { Current.platform = nil }

  def open_host_menu
    find('#userNavbarDropdownMenuLink').click
    expect(page).to have_css('#userNavbarDropdownMenuLink[aria-expanded="true"]', wait: 10)
    find('#host-nav-item a.dropdown-toggle', wait: 10).click
    expect(page).to have_css(entry, wait: 10)
  end

  it 'lists the billing pages, each a link to the page it names' do
    open_host_menu

    hrefs = page.all('#host-nav-item a.dropdown-item[data-identifier^="billing-"]').map { |link| URI.parse(link[:href]).path }
    expect(hrefs).to include(*%w[plans processor_settings sales subscribers tax_registrations agreement_requirements promotions
                                 credit_accounts allowances].map { |name| "/#{I18n.default_locale}/billing/#{name}" })
  end

  it 'passes WCAG 2.2 AA accessibility checks with the menu open' do
    open_host_menu

    expect(page).to be_axe_clean
      .within('#host-nav-item')
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :wcag22aa)
  end
end
