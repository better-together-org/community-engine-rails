# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'accepting a platform invitation' do
  let!(:invitation) do
    create(:better_together_platform_invitation,
           invitable: configure_host_platform)
  end
  let(:person) { build(:better_together_person) }
  let(:password) { Faker::Internet.password(min_length: 12, max_length: 20) }

  scenario 'by signing up a new user', :unauthenticated do
    sign_up_new_user(invitation.token, invitation.invitee_email, password, person)
    sign_in_user(invitation.invitee_email, password)
    expect(page).to have_content('Signed in successfully.')
  end
end
