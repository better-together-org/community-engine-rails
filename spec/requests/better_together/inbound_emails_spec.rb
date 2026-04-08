# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::InboundEmails' do
  let(:password) { 'test-ingress-password' }
  let(:headers) do
    {
      'CONTENT_TYPE' => 'message/rfc822',
      'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials('actionmailbox', password)
    }
  end
  let(:raw_email) do
    <<~MAIL
      From: Sender Example <sender@example.test>
      To: community+inbound-community@example.test
      Subject: Hello
      Message-ID: <#{SecureRandom.uuid}@example.test>
      MIME-Version: 1.0
      Content-Type: text/plain; charset=UTF-8

      Plain text body
    MAIL
  end

  around do |example|
    original = BetterTogether.inbound_email_ingress_password
    BetterTogether.inbound_email_ingress_password = password
    example.run
  ensure
    BetterTogether.inbound_email_ingress_password = original
  end

  it 'accepts RFC822 email with valid basic auth' do
    expect do
      post BetterTogether::Engine.routes.url_helpers.inbound_email_relay_path, params: raw_email, headers:
    end.to change(ActionMailbox::InboundEmail, :count).by(1)

    expect(response).to have_http_status(:no_content)
  end

  it 'rejects requests without valid credentials' do
    post BetterTogether::Engine.routes.url_helpers.inbound_email_relay_path,
         params: raw_email,
         headers: headers.merge('HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials('actionmailbox', 'wrong'))

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects unsupported content types' do
    post BetterTogether::Engine.routes.url_helpers.inbound_email_relay_path,
         params: raw_email,
         headers: headers.merge('CONTENT_TYPE' => 'application/json')

    expect(response).to have_http_status(:unsupported_media_type)
  end
end
