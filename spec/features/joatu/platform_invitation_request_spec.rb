# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Platform invitation request' do
  include BetterTogether::DeviseSessionHelpers
  scenario 'visitor requests invite and sees matching offer' do # rubocop:todo RSpec/NoExpectationExample
    # create(:better_together_joatu_offer, target_type: 'BetterTogether::PlatformInvitation', name: 'Invite Offer')

    # visit better_together.new_joatu_request_path(locale: I18n.default_locale)
    # fill_in 'name_en', with: 'Visitor'
    # # Select the seeded category expected for matching
    # select 'Platform Invitations', from: 'request_category_ids'
    # fill_in 'description_en', with: 'Please invite me'
    # click_button 'Create Request'

    # expect(page).to have_content('Invite Offer')
  end
end
