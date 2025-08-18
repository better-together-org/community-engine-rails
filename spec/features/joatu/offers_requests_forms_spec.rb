# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Joatu offer and request forms', type: :feature do
  include BetterTogether::DeviseSessionHelpers

  let!(:category) { create(:better_together_joatu_category) }

  before do
    configure_host_platform
    login_as_platform_manager
  end

  scenario 'creating an offer' do
    visit new_joatu_offer_path(locale: I18n.default_locale)
    fill_in name: 'joatu_offer[name_en]', with: 'Bike repair'
    first('trix-editor').click.set('I can repair bikes')
    select category.name, from: 'joatu_offer[category_ids][]'
    find_button('Save Offer', match: :first).click
    expect(page).to have_content('Bike repair')
  end

  scenario 'creating a request' do
    visit new_joatu_request_path(locale: I18n.default_locale)
    fill_in name: 'joatu_request[name_en]', with: 'Need a ladder'
    first('trix-editor').click.set('Looking to borrow a ladder')
    select category.name, from: 'joatu_request[category_ids][]'
    find_button('Save Request', match: :first).click
    expect(page).to have_content('Need a ladder')
  end
end
