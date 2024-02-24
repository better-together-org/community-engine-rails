require 'rails_helper'

describe BetterTogether::ConfirmationsController, type: :request do
  let(:user) { create(:user) }
  let(:confirmation_token) { user.send(:generate_confirmation_token!) }
  context 'When confirming an account' do
    before do
      get confirmation_url
    end

    # context 'when the token is valid' do
    #   let (:confirmation_url) { better_together.user_confirmation_path(confirmation_token: confirmation_token) }

    #   it 'returns 201' do
    #     expect(response.status).to eq(201)
    #   end
    # end

    # context 'when the token is invalid' do
    #   let (:confirmation_url) { better_together.user_confirmation_path(confirmation_token: 'hgduagduhagsdhak') }

    #   it 'returns 422' do
    #     expect(response.status).to eq(422)
    #   end
    # end
  end

  context 'When requesting a new confirmation email' do
    let(:resend_confirmation_url) { better_together.user_confirmation_path }

    before do
      post resend_confirmation_url, params:
    end

    context 'when the email exists' do
      let(:params) do
        {
          user: {
            email: user.email
          }
        }
      end

      it 'returns 201' do
        expect(response.status).to eq(201)
      end
    end

    context 'when the email does not exist' do
      let(:params) do
        {
          user: {
            email: 'nothingexistingwiththis@here.com'
          }
        }
      end

      it 'returns 422' do
        expect(response.status).to eq(422)
      end
    end
  end
end
