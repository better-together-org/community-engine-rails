# frozen_string_literal: true

require 'rails_helper'

# A steward picks the buyer of a sale in person by searching the person select (SlimSelect), not by typing an
# exact handle. Follows the layered-waiting pattern for SlimSelect (AGENTS.md).
RSpec.describe 'Billing walk-up sale buyer lookup', :accessibility, :js, :skip_host_setup, retry: 0 do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let!(:member) { create(:better_together_person, name: 'Marguerite Okonkwo') }

  before do
    configure_host_platform
    enable_offline('cash')
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     amount_cents: 4500, currency: 'USD')
    create(:better_together_person_platform_membership, joinable: host_platform, member:)
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/walk_up_sale/new"
  end

  it 'finds a member by part of their name and selects them as the buyer' do
    expect(page).to have_css('#billing-walk-up-buyer', visible: :all, wait: 10)
    expect(page).to have_css('#billing-walk-up-form .ss-main', wait: 5)
    all('#billing-walk-up-form .ss-main').last.click
    find('.ss-content .ss-search input').set('okonk')
    find('.ss-content .ss-option', text: 'Marguerite Okonkwo', wait: 10).click

    expect(page).to have_field('billing-walk-up-buyer', with: member.id, type: :select, visible: :all)
  end

  it 'records a sale for someone who is not on the platform yet, from their name and email' do
    purchase_agreements_for(host_platform)
    fill_in 'billing-walk-up-buyer-name', with: 'Odalys Fortier'
    fill_in 'billing-walk-up-buyer-email', with: 'odalys@example.test'
    fill_in 'billing-walk-up-address-line1', with: '1 Water St'
    fill_in 'billing-walk-up-address-city-name', with: 'St. John\'s'
    fill_in 'billing-walk-up-address-country-name', with: 'Canada'
    check 'billing-walk-up-agreements'
    click_button 'billing-walk-up-submit'

    expect(page).to have_no_css('#billing-walk-up-form', wait: 10)
    order = BetterTogether::Billing::Order.order(:created_at).last
    expect(order.buyer.name).to eq('Odalys Fortier')
    expect(order.buyer_email).to eq('odalys@example.test')
  end

  it 'passes the accessibility scan' do
    expect(page).to have_css('#billing-walk-up-form .ss-main', wait: 10)

    expect(page).to be_axe_clean.within('#billing-walk-up-form')
                                .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end
end
