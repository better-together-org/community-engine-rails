# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::MessageRequestsController' do
  include RequestSpecHelper

  let(:locale) { I18n.default_locale }
  let(:platform_manager_user) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let(:regular_user) { BetterTogether::User.find_by(email: 'user@example.test') }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }

  describe 'GET /:locale/message_requests (index)' do
    context 'when authenticated', :as_user do
      it 'returns 200' do
        get better_together.message_requests_path(locale:)
        expect(response).to have_http_status(:ok)
      end

      it 'only shows pending requests addressed to the current person' do
        other_person = create(:better_together_person)
        received_request = create(:better_together_message_request,
                                  sender: other_person,
                                  recipient: regular_user.person,
                                  platform:)

        get better_together.message_requests_path(locale:)
        expect(response.body).to include(received_request.id)
      end
    end
  end

  describe 'POST /:locale/message_requests (create)' do
    let(:recipient) { create(:better_together_person) }

    context 'when authenticated', :as_user do
      it 'creates a pending message request and redirects' do
        expect do
          post better_together.message_requests_path(locale:), params: {
            message_request: {
              recipient_id: recipient.id,
              note: 'Hi, I would like to connect.'
            }
          }
        end.to change(BetterTogether::MessageRequest, :count).by(1)

        expect(response).to redirect_to(better_together.conversations_path(locale:))
      end

      it 'sets the current platform on the request' do
        post better_together.message_requests_path(locale:), params: {
          message_request: {
            recipient_id: recipient.id,
            note: 'Platform assignment test.'
          }
        }

        created = BetterTogether::MessageRequest.order(created_at: :desc).first
        expect(created.platform).to eq(platform)
      end

      it 'sets the sender to the current person' do
        post better_together.message_requests_path(locale:), params: {
          message_request: {
            recipient_id: recipient.id,
            note: 'Sender assignment test.'
          }
        }

        created = BetterTogether::MessageRequest.order(created_at: :desc).first
        expect(created.sender).to eq(regular_user.person)
      end

      context 'with invalid params (missing note)' do
        it 'does not create a request and redirects with an error flash' do
          expect do
            post better_together.message_requests_path(locale:), params: {
              message_request: {
                recipient_id: recipient.id,
                note: ''
              }
            }
          end.not_to change(BetterTogether::MessageRequest, :count)

          expect(response).to be_redirect
          follow_redirect!
          expect(response.body).to include('alert')
        end
      end
    end
  end

  describe 'PUT /:locale/message_requests/:id/accept' do
    let(:sender_user) do
      create(:user, :confirmed, email: 'sender@example.test', password: 'SecureTest123!@#')
    end
    let(:message_request) do
      create(:better_together_message_request,
             sender: sender_user.person,
             recipient: regular_user.person,
             platform:)
    end

    context 'as the recipient', :as_user do
      it 'accepts the request and redirects to conversations' do
        put better_together.accept_message_request_path(message_request, locale:)
        expect(response).to redirect_to(better_together.conversations_path(locale:))
        expect(message_request.reload).to be_accepted
      end

      it 'creates a messaging grant' do
        expect do
          put better_together.accept_message_request_path(message_request, locale:)
        end.to change(BetterTogether::PersonMessagingGrant, :count).by(1)
      end
    end
  end

  describe 'PUT /:locale/message_requests/:id/decline' do
    let(:sender_user) do
      create(:user, :confirmed, email: 'decliner_sender@example.test', password: 'SecureTest123!@#')
    end
    let(:message_request) do
      create(:better_together_message_request,
             sender: sender_user.person,
             recipient: regular_user.person,
             platform:)
    end

    context 'as the recipient', :as_user do
      it 'declines the request and redirects' do
        put better_together.decline_message_request_path(message_request, locale:)
        expect(response).to be_redirect
        expect(message_request.reload).to be_declined
      end

      it 'does not create a messaging grant' do
        expect do
          put better_together.decline_message_request_path(message_request, locale:)
        end.not_to change(BetterTogether::PersonMessagingGrant, :count)
      end
    end
  end
end
