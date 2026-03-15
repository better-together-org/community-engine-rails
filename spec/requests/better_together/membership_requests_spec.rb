# frozen_string_literal: true

require 'rails_helper'

# @tagged hermetic
RSpec.describe 'BetterTogether::MembershipRequests (public HTML)', type: :request do
  let!(:platform) { BetterTogether::Platform.first || create(:better_together_platform) }
  let!(:community) { create(:better_together_community) }
  let(:new_path)    { "/#{I18n.locale}/c/#{community.slug}/membership_requests/new" }
  let(:create_path) { "/#{I18n.locale}/c/#{community.slug}/membership_requests" }

  let(:valid_params) do
    {
      joatu_membership_request: {
        requestor_name: 'Alice Example',
        requestor_email: 'alice@example.test',
        referral_source: 'A friend',
        description: 'I want to help the community.'
      }
    }
  end

  describe 'GET /c/:community_id/membership_requests/new' do
    it 'renders the form without authentication' do
      get new_path
      expect(response).to have_http_status(:ok)
    end

    it 'renders a form tag pointing to the create path' do
      get new_path
      expect(response.body).to include('membership_request')
    end
  end

  describe 'POST /c/:community_id/membership_requests' do
    context 'with valid params (unauthenticated)' do
      it 'creates the membership request' do
        expect {
          post create_path, params: valid_params
        }.to change(BetterTogether::Joatu::MembershipRequest, :count).by(1)
      end

      it 'renders the success page' do
        post create_path, params: valid_params
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(
          I18n.t('better_together.membership_requests.success.heading',
                 default: 'Request Received')
        )
      end

      it 'sets creator to nil (unauthenticated)' do
        post create_path, params: valid_params
        mr = BetterTogether::Joatu::MembershipRequest.last
        expect(mr.creator).to be_nil
      end

      it 'sets the target community' do
        post create_path, params: valid_params
        mr = BetterTogether::Joatu::MembershipRequest.last
        expect(mr.target).to eq(community)
      end

      it 'sets the requestor email' do
        post create_path, params: valid_params
        mr = BetterTogether::Joatu::MembershipRequest.last
        expect(mr.requestor_email).to eq('alice@example.test')
      end
    end

    context 'with invalid params (missing required fields)' do
      let(:invalid_params) do
        {
          joatu_membership_request: {
            requestor_name: '',
            requestor_email: 'not-an-email',
            description: ''
          }
        }
      end

      it 're-renders the form with 422' do
        post create_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create a membership request' do
        expect {
          post create_path, params: invalid_params
        }.not_to change(BetterTogether::Joatu::MembershipRequest, :count)
      end
    end

    context 'with captcha hook' do
      it 'renders 422 when captcha validation fails' do
        # Simulate a host app that overrides validate_captcha_if_enabled? to return false.
        # We stub the controller method directly.
        allow_any_instance_of(BetterTogether::MembershipRequestsController) # rubocop:disable RSpec/AnyInstance
          .to receive(:validate_captcha_if_enabled?).and_return(false)

        post create_path, params: valid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
