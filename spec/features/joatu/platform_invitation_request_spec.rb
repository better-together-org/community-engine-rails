# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Platform invitation request', type: :feature do
  include BetterTogether::DeviseSessionHelpers

  scenario 'visitor requests invite and sees matching offer' do
    configure_host_platform

    create(:better_together_joatu_offer, target_type: 'BetterTogether::PlatformInvitation', name: 'Invite Offer')

    visit better_together.new_joatu_request_path
    fill_in 'Name', with: 'Visitor'
    fill_in 'Description', with: 'Please invite me'
    click_button 'Create Request'

    expect(page).to have_content('Invite Offer')
  end
end
