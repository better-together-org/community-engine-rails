# frozen_string_literal: true

require 'rails_helper'

# A steward finds someone's store credit by searching the person select (SlimSelect), not by typing an exact
# handle. Follows the layered-waiting pattern for SlimSelect (AGENTS.md).
RSpec.describe 'Billing credit person lookup', :accessibility, :js, :skip_host_setup, retry: 0 do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let!(:member) { create(:better_together_person, name: 'Marguerite Okonkwo') }

  before do
    configure_host_platform
    enable_offline('cash')
    create(:better_together_person_platform_membership, joinable: host_platform, member:)
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/credit_accounts"
  end

  it 'finds a member by part of their name and opens their credit' do
    expect(page).to have_css('#billing-credit-lookup-person', visible: :all, wait: 10)
    expect(page).to have_css('#billing-credit-lookup-form .ss-main', wait: 5)
    find('#billing-credit-lookup-form .ss-main').click
    find('.ss-content .ss-search input').set('okonk')
    find('.ss-content .ss-option', text: 'Marguerite Okonkwo', wait: 10).click
    click_button 'billing-credit-lookup-btn'

    expect(page).to have_css('#billing-credit-holder', text: 'Marguerite Okonkwo', wait: 10)
    expect(page).to have_css('#billing-credit-grant-form')
  end

  it 'passes the accessibility scan' do
    expect(page).to have_css('#billing-credit-lookup-form .ss-main', wait: 10)

    expect(page).to be_axe_clean.within('#billing-credit-lookup-form')
                                .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end
end
