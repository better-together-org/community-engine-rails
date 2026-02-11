# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invitation-Required Platform Registration', :no_auth, :skip_host_setup do
  include AutomaticTestConfiguration

  let(:valid_user_params) do
    email_suffix = SecureRandom.hex(4)
    {
      email: "invitee-#{email_suffix}@example.com",
      password: 'SecureTest123!@#',
      password_confirmation: 'SecureTest123!@#',
      person_attributes: {
        name: 'Invited User',
        identifier: "invited-user-#{email_suffix}"
      }
    }
  end

  let(:invitee_email) { valid_user_params[:email] }

  let!(:privacy_agreement) do
    BetterTogether::Agreement.find_or_create_by(identifier: 'privacy_policy') do |a|
      a.title = 'Privacy Policy'
      a.creator = create(:better_together_person)
    end
  end

  let!(:terms_agreement) do
    BetterTogether::Agreement.find_or_create_by(identifier: 'terms_of_service') do |a|
      a.title = 'Terms of Service'
      a.creator = create(:better_together_person)
    end
  end

  let!(:code_of_conduct_agreement) do
    BetterTogether::Agreement.find_or_create_by(identifier: 'code_of_conduct') do |a|
      a.title = 'Code of Conduct'
      a.creator = create(:better_together_person)
    end
  end

  describe 'when platform requires_invitation is true' do
    let!(:platform) do
      platform = configure_host_platform
      platform.update!(requires_invitation: true)
      platform
    end

    context 'without any invitation code' do
      it 'blocks registration and shows error' do
        expect do
          post '/en/users', params: {
            user: valid_user_params,
            terms_of_service_agreement: '1',
            privacy_policy_agreement: '1',
            code_of_conduct_agreement: '1'
          }
        end.not_to change(BetterTogether::User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        # Should show error message about invitation being required
        expect_html_content(
          I18n.t('better_together.registrations.invitation_required',
                 default: 'An invitation code is required to register')
        )
      end

      it 'shows invitation code prompt on GET new' do
        get '/en/users/sign-up'
        expect(response).to have_http_status(:ok)
        expect_html_content(I18n.t('devise.registrations.new.invitation_required'))
        expect_html_content(I18n.t('devise.registrations.new.invitation_code'))
      end
    end

    context 'with valid platform invitation in params' do
      let!(:platform_role) { BetterTogether::Role.find_by!(identifier: 'platform_manager') }
      let!(:invitation) do
        create(:better_together_platform_invitation,
               invitable: platform,
               invitee_email: invitee_email,
               platform_role: platform_role,
               status: 'pending')
      end

      it 'allows registration and accepts invitation' do
        expect(invitation.reload.status).to eq('pending')

        post '/en/users', params: {
          user: valid_user_params,
          terms_of_service_agreement: '1',
          privacy_policy_agreement: '1',
          code_of_conduct_agreement: '1',
          invitation_code: invitation.token
        }

        user = BetterTogether::User.find_by(email: invitee_email)
        expect(user).to be_present
        expect(user.person).to be_present

        # Verify invitation acceptance
        expect(invitation.reload.status).to eq('accepted')
        expect(invitation.invitee).to eq(user.person)

        # Verify platform role assignment
        membership = user.person.person_platform_memberships.find_by(joinable_id: platform.id)
        expect(membership).to be_present
        expect(membership.role).to eq(platform_role)
      end

      it 'shows registration form with invitation prefilled on GET new' do
        get "/en/users/sign-up?invitation_code=#{invitation.token}"
        expect(response).to have_http_status(:ok)
        # Should show normal registration form, not invitation prompt
        expect_html_content(I18n.t('devise.registrations.new.sign_up'))
        # Hidden field should contain invitation code
        expect(response.body).to include('invitation-code-field')
        expect(response.body).to include(invitation.token)
      end
    end

    context 'with valid platform invitation in session' do
      let!(:platform_role) { BetterTogether::Role.find_by!(identifier: 'platform_manager') }
      let!(:invitation) do
        create(:better_together_platform_invitation,
               invitable: platform,
               invitee_email: invitee_email,
               platform_role: platform_role,
               status: 'pending')
      end

      before do
        # Simulate invitation token stored in session (from previous page visit)
        post '/en/users', params: { invitation_code: invitation.token }, headers: {
          'HTTP_REFERER' => '/en/users/sign_up'
        }
      end

      it 'allows registration using session invitation' do
        # First, set invitation in session via GET new
        get "/en/users/sign-up?invitation_code=#{invitation.token}"
        expect(response).to have_http_status(:ok)

        # Then attempt registration
        expect do
          post '/en/users', params: {
            user: valid_user_params,
            terms_of_service_agreement: '1',
            privacy_policy_agreement: '1',
            code_of_conduct_agreement: '1'
          }
        end.to change(BetterTogether::User, :count).by(1)

        user = BetterTogether::User.find_by(email: invitee_email)
        expect(user).to be_present
        expect(invitation.reload.status).to eq('accepted')
      end
    end

    context 'with valid community invitation' do
      let!(:community) { create(:better_together_community, identifier: "test-community-#{SecureRandom.hex(4)}") }
      let!(:invitation) do
        create(:better_together_community_invitation,
               invitable: community,
               invitee_email: invitee_email,
               status: 'pending')
      end

      it 'allows registration with community invitation code' do
        expect do
          post '/en/users', params: {
            user: valid_user_params,
            terms_of_service_agreement: '1',
            privacy_policy_agreement: '1',
            code_of_conduct_agreement: '1',
            invitation_code: invitation.token
          }
        end.to change(BetterTogether::User, :count).by(1)

        user = BetterTogether::User.find_by(email: invitee_email)
        expect(user).to be_present

        # Verify invitation acceptance
        expect(invitation.reload.status).to eq('accepted')

        # Verify community membership
        membership = user.person.person_community_memberships.find_by(joinable_id: community.id)
        expect(membership).to be_present
      end
    end

    context 'with valid event invitation' do
      let!(:event) { create(:better_together_event, identifier: "test-event-#{SecureRandom.hex(4)}") }
      let!(:invitation) do
        create(:better_together_event_invitation,
               invitable: event,
               invitee_email: invitee_email,
               status: 'pending')
      end

      it 'allows registration with event invitation code' do
        expect do
          post '/en/users', params: {
            user: valid_user_params,
            terms_of_service_agreement: '1',
            privacy_policy_agreement: '1',
            code_of_conduct_agreement: '1',
            invitation_code: invitation.token
          }
        end.to change(BetterTogether::User, :count).by(1)
                                                   .and change(BetterTogether::EventAttendance, :count).by(1)

        user = BetterTogether::User.find_by(email: invitee_email)
        expect(user).to be_present

        # Verify invitation acceptance
        expect(invitation.reload.status).to eq('accepted')

        # Verify event attendance
        attendance = BetterTogether::EventAttendance.find_by(event: event, person: user.person)
        expect(attendance).to be_present
      end
    end

    context 'with invalid invitation code' do
      it 'blocks registration and shows error' do
        expect do
          post '/en/users', params: {
            user: valid_user_params,
            terms_of_service_agreement: '1',
            privacy_policy_agreement: '1',
            code_of_conduct_agreement: '1',
            invitation_code: 'invalid-token-12345'
          }
        end.not_to change(BetterTogether::User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect_html_content(
          I18n.t('better_together.registrations.invalid_invitation',
                 default: 'Invalid or expired invitation code')
        )
      end
    end

    context 'with expired invitation code' do
      let!(:invitation) do
        create(:better_together_platform_invitation,
               invitable: platform,
               invitee_email: invitee_email,
               status: 'pending',
               valid_until: 1.day.ago) # Expired
      end

      it 'blocks registration and shows error' do
        expect do
          post '/en/users', params: {
            user: valid_user_params,
            terms_of_service_agreement: '1',
            privacy_policy_agreement: '1',
            code_of_conduct_agreement: '1',
            invitation_code: invitation.token
          }
        end.not_to change(BetterTogether::User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect_html_content(
          I18n.t('better_together.registrations.invalid_invitation',
                 default: 'Invalid or expired invitation code')
        )
      end
    end

    context 'with accepted (already used) invitation code' do
      let!(:invitation) do
        create(:better_together_platform_invitation,
               invitable: platform,
               invitee_email: invitee_email,
               status: 'accepted') # already accepted
      end

      it 'blocks registration and shows error' do
        expect do
          post '/en/users', params: {
            user: valid_user_params,
            terms_of_service_agreement: '1',
            privacy_policy_agreement: '1',
            code_of_conduct_agreement: '1',
            invitation_code: invitation.token
          }
        end.not_to change(BetterTogether::User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect_html_content(
          I18n.t('better_together.registrations.invalid_invitation',
                 default: 'Invalid or expired invitation code')
        )
      end
    end
  end

  describe 'when platform requires_invitation is false' do
    before do
      platform = configure_host_platform
      platform.update!(requires_invitation: false)
    end

    it 'allows open registration without invitation code' do
      expect do
        post '/en/users', params: {
          user: valid_user_params,
          terms_of_service_agreement: '1',
          privacy_policy_agreement: '1',
          code_of_conduct_agreement: '1'
        }
      end.to change(BetterTogether::User, :count).by(1)

      user = BetterTogether::User.find_by(email: invitee_email)
      expect(user).to be_present
      expect(user.person).to be_present
    end

    it 'shows normal registration form on GET new' do
      get '/en/users/sign-up'
      expect(response).to have_http_status(:ok)
      expect_html_content(I18n.t('devise.registrations.new.sign_up'))
      # Should NOT show invitation requirement message
      expect_no_html_content(I18n.t('devise.registrations.new.invitation_required'))
    end

    it 'still accepts invitation codes if provided' do
      community = create(:better_together_community)
      invitation = create(:better_together_community_invitation,
                          invitable: community,
                          invitee_email: invitee_email,
                          status: 'pending')

      expect do
        post '/en/users', params: {
          user: valid_user_params,
          terms_of_service_agreement: '1',
          privacy_policy_agreement: '1',
          code_of_conduct_agreement: '1',
          invitation_code: invitation.token
        }
      end.to change(BetterTogether::User, :count).by(1)

      user = BetterTogether::User.find_by(email: invitee_email)
      expect(invitation.reload.status).to eq('accepted')
      expect(invitation.invitee).to eq(user.person)
    end
  end

  describe 'edge cases' do
    let!(:platform) do
      platform = configure_host_platform
      platform.update!(requires_invitation: true)
      platform
    end

    context 'when invitation email does not match registration email' do
      let!(:invitation) do
        create(:better_together_platform_invitation,
               invitable: platform,
               invitee_email: 'different-email@example.com', # Different email
               status: 'pending')
      end

      it 'still allows registration (invitation email is a hint, not a constraint)' do
        # NOTE: Current system allows this - invitation email is for sending the invitation,
        # not for validating who can use it. The token itself is the authorization.
        expect do
          post '/en/users', params: {
            user: valid_user_params, # Using different email
            terms_of_service_agreement: '1',
            privacy_policy_agreement: '1',
            code_of_conduct_agreement: '1',
            invitation_code: invitation.token
          }
        end.to change(BetterTogether::User, :count).by(1)

        user = BetterTogether::User.find_by(email: invitee_email)
        expect(user).to be_present
        expect(invitation.reload.status).to eq('accepted')
      end
    end

    context 'when user provides both valid params and session invitation tokens' do
      let!(:platform_invitation) do
        create(:better_together_platform_invitation,
               invitable: platform,
               invitee_email: invitee_email,
               status: 'pending')
      end

      let!(:community) { create(:better_together_community) }
      let!(:community_invitation) do
        create(:better_together_community_invitation,
               invitable: community,
               invitee_email: invitee_email,
               status: 'pending')
      end

      it 'processes invitation from params and session invitations' do
        # Set community invitation in session first
        get "/en/users/sign-up?invitation_code=#{community_invitation.token}"

        # Then register with platform invitation in params
        expect do
          post '/en/users', params: {
            user: valid_user_params,
            terms_of_service_agreement: '1',
            privacy_policy_agreement: '1',
            code_of_conduct_agreement: '1',
            invitation_code: platform_invitation.token
          }
        end.to change(BetterTogether::User, :count).by(1)

        user = BetterTogether::User.find_by(email: invitee_email)
        expect(user).to be_present

        # Both invitations should be accepted
        expect(platform_invitation.reload.status).to eq('accepted')
        expect(community_invitation.reload.status).to eq('accepted')
      end
    end
  end
end
