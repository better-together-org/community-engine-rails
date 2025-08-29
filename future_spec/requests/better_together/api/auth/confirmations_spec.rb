# frozen_string_literal: true

require 'rails_helper'

describe BetterTogether::ConfirmationsController do # rubocop:todo RSpec/SpecFilePathFormat
  let(:user) { create(:user) }
  let(:confirmation_token) { user.send(:generate_confirmation_token!) }

  context 'When requesting a new confirmation email' do # rubocop:todo RSpec/ContextWording
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
        expect(response).to have_http_status(:created)
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
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
