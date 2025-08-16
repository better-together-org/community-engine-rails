# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Joatu offer and request forms', type: :feature do
  include BetterTogether::DeviseSessionHelpers

  let!(:host_platform) { configure_host_platform }
  let!(:category) { create(:better_together_joatu_category) }

  before do
    login_as_platform_manager
  end

  scenario 'creating an offer' do
    visit new_joatu_offer_path(locale: I18n.default_locale)
    fill_in name: 'offer[name_en]', with: 'Bike repair'
    fill_in name: 'offer[description_en]', with: 'I can repair bikes'
    select category.name, from: 'offer_category_ids'
    click_button 'Save Offer'
    expect(page).to have_content('Bike repair')
  end

  scenario 'creating a request' do
    visit new_joatu_request_path(locale: I18n.default_locale)
    fill_in name: 'request[name_en]', with: 'Need a ladder'
    fill_in name: 'request[description_en]', with: 'Looking to borrow a ladder'
    select category.name, from: 'request_category_ids'
    click_button 'Save Request'
    expect(page).to have_content('Need a ladder')
  end
end
