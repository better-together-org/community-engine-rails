# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'creating a platform invitation' do
  include BetterTogether::DeviseSessionHelpers

  let!(:host_platform) do
    configure_host_platform
  end
  let(:invitee_email) { Faker::Internet.unique.email }

  before do
    login_as_platform_manager
  end

  scenario 'with valid inputs' do # rubocop:todo RSpec/ExampleLength
    visit platform_path(host_platform, locale: I18n.default_locale)
    within '#newInvitationModal' do
      select 'Platform Invitation', from: 'platform_invitation[type]'
      select 'Community Facilitator', from: 'platform_invitation[community_role_id]'
      select 'Platform Manager', from: 'platform_invitation[platform_role_id]'
      fill_in 'platform_invitation[invitee_email]', with: invitee_email
      click_button 'Invite'
    end
    expect(page).to have_content(invitee_email)
  end
end
