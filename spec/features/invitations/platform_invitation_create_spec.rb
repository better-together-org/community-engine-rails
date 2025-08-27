# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'creating a platform invitation', :as_platform_manager do
  include BetterTogether::DeviseSessionHelpers

  let!(:host_platform) do
  end
  let(:invitee_email) { Faker::Internet.unique.email }

  before do
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
