# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Joatu offer and request forms', :as_platform_manager do
  let!(:category) { create(:better_together_joatu_category) }

  before do
    fill_in name: 'joatu_offer[name_en]', with: 'Bike repair'
    # Populate the underlying ActionText hidden input for current locale
    find("input[name='joatu_offer[description_#{I18n.default_locale}]']", visible: false)
      .set('I can repair bikes')
    select category.name, from: 'joatu_offer[category_ids][]'
    find_button('Save Offer', match: :first).click
  end

  it 'shows created offer' do
    expect(page).to have_content('Bike repair')
  end

  scenario 'creating a request' do # rubocop:todo RSpec/ExampleLength
    visit new_joatu_request_path(locale: I18n.default_locale)
    fill_in name: 'joatu_request[name_en]', with: 'Need a ladder'
    # Populate the underlying ActionText hidden input for current locale
    find("input[name='joatu_request[description_#{I18n.default_locale}]']", visible: false)
      .set('Looking to borrow a ladder')
    select category.name, from: 'joatu_request[category_ids][]'
    find_button('Save Request', match: :first).click
    expect(page).to have_content('Need a ladder')
  end
end
