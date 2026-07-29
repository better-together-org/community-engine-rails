# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Api::V1::JoatuAgreements C3 cancel', :no_auth do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:token) { api_sign_in_and_get_token(user) }
  let(:auth_headers) { api_auth_headers(user, token: token) }

  describe 'POST /api/v1/joatu_agreements/:id/cancel' do
    let(:priced_offer) { create(:better_together_joatu_offer, creator: person, c3_price_millitokens: 20_000) }
    let(:other_user) { create(:better_together_user, :confirmed) }
    let(:other_request) { create(:better_together_joatu_request, creator: other_user.person) }
    let(:agreement) { create(:better_together_joatu_agreement, offer: priced_offer, request: other_request) }
    let(:url) { "/api/v1/joatu_agreements/#{agreement.id}/cancel" }

    before do
      # priced_offer carries a c3_price_millitokens of 20_000 (20 Tree Seeds).
      # agreement.accept! locks that full price from the payer (request.creator,
      # i.e. other_user.person) via Balance#lock_millitokens!, so the payer's
      # balance must be credited with at least that much up front or the lock
      # raises BetterTogether::C3::Balance::InsufficientBalance.
      BetterTogether::C3::Balance.find_or_create_by!(holder: other_user.person).credit!(20.0)
      agreement.accept!
    end

    context 'when authenticated as participant' do
      before { post url, headers: auth_headers }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'cancels the agreement' do
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['status']).to eq('cancelled')
        expect(json['data']['attributes']['decision_made_at']).to be_present
      end
    end
  end
end
