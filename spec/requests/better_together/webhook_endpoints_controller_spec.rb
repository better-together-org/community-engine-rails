# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::WebhookEndpointsController' do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }

  describe 'GET /host/webhook_endpoints (index)', :as_platform_manager do
    let!(:endpoint) do
      create(:better_together_webhook_endpoint,
             name: 'My Integration Webhook',
             person: platform_manager.person)
    end

    it 'renders the index page successfully' do
      get better_together.webhook_endpoints_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'displays webhook endpoint names' do
      get better_together.webhook_endpoints_path(locale:)
      expect_html_content('My Integration Webhook')
    end

    it 'includes a link to create a new webhook' do
      get better_together.webhook_endpoints_path(locale:)
      expect(response.body).to include(better_together.new_webhook_endpoint_path(locale:))
    end
  end

  describe 'GET /host/webhook_endpoints/:id (show)', :as_platform_manager do
    let(:endpoint) do
      create(:better_together_webhook_endpoint,
             name: 'Show Test Webhook',
             person: platform_manager.person)
    end

    it 'renders the show page successfully' do
      get better_together.webhook_endpoint_path(locale:, id: endpoint.id)
      expect(response).to have_http_status(:ok)
    end

    it 'displays the endpoint name' do
      get better_together.webhook_endpoint_path(locale:, id: endpoint.id)
      expect_html_content('Show Test Webhook')
    end

    it 'displays the endpoint URL' do
      get better_together.webhook_endpoint_path(locale:, id: endpoint.id)
      expect_html_content(endpoint.url)
    end
  end

  describe 'GET /host/webhook_endpoints/new', :as_platform_manager do
    it 'renders the new webhook form' do
      get better_together.new_webhook_endpoint_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'includes form fields' do
      get better_together.new_webhook_endpoint_path(locale:)
      expect(response.body).to include('webhook_endpoint[name]')
      expect(response.body).to include('webhook_endpoint[url]')
    end
  end

  describe 'POST /host/webhook_endpoints', :as_platform_manager do
    let(:valid_params) do
      {
        webhook_endpoint: {
          name: 'New Test Webhook',
          url: 'https://example.com/webhooks/receive',
          description: 'A test webhook endpoint',
          events: 'community.created, post.created',
          active: true
        }
      }
    end

    it 'creates a new webhook endpoint' do
      expect do
        post better_together.webhook_endpoints_path(locale:), params: valid_params
      end.to change(BetterTogether::WebhookEndpoint, :count).by(1)
    end

    it 'redirects after successful creation' do
      post better_together.webhook_endpoints_path(locale:), params: valid_params
      expect(response).to have_http_status(:found)
    end

    it 'assigns the current user as the webhook owner' do
      post better_together.webhook_endpoints_path(locale:), params: valid_params
      endpoint = BetterTogether::WebhookEndpoint.last
      expect(endpoint.person).to eq(platform_manager.person)
    end

    it 'generates a signing secret automatically' do
      post better_together.webhook_endpoints_path(locale:), params: valid_params
      endpoint = BetterTogether::WebhookEndpoint.last
      expect(endpoint.secret).to be_present
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          webhook_endpoint: {
            name: '',
            url: 'not-a-url'
          }
        }
      end

      it 'does not create a webhook endpoint' do
        expect do
          post better_together.webhook_endpoints_path(locale:), params: invalid_params
        end.not_to change(BetterTogether::WebhookEndpoint, :count)
      end

      it 'returns unprocessable entity status' do
        post better_together.webhook_endpoints_path(locale:), params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'GET /host/webhook_endpoints/:id/edit', :as_platform_manager do
    let(:endpoint) do
      create(:better_together_webhook_endpoint,
             name: 'Edit Test Webhook',
             person: platform_manager.person)
    end

    it 'renders the edit form' do
      get better_together.edit_webhook_endpoint_path(locale:, id: endpoint.id)
      expect(response).to have_http_status(:ok)
    end

    it 'populates the form with existing data' do
      get better_together.edit_webhook_endpoint_path(locale:, id: endpoint.id)
      expect_html_content('Edit Test Webhook')
    end
  end

  describe 'PATCH /host/webhook_endpoints/:id', :as_platform_manager do
    let(:endpoint) do
      create(:better_together_webhook_endpoint,
             name: 'Original Name',
             person: platform_manager.person)
    end

    let(:update_params) do
      {
        webhook_endpoint: {
          name: 'Updated Webhook Name'
        }
      }
    end

    it 'updates the webhook endpoint' do
      patch better_together.webhook_endpoint_path(locale:, id: endpoint.id), params: update_params
      endpoint.reload
      expect(endpoint.name).to eq('Updated Webhook Name')
    end

    it 'redirects after successful update' do
      patch better_together.webhook_endpoint_path(locale:, id: endpoint.id), params: update_params
      expect(response).to have_http_status(:found)
    end
  end

  describe 'DELETE /host/webhook_endpoints/:id', :as_platform_manager do
    let!(:endpoint) do
      create(:better_together_webhook_endpoint,
             name: 'Delete Test',
             person: platform_manager.person)
    end

    it 'deletes the webhook endpoint' do
      expect do
        delete better_together.webhook_endpoint_path(locale:, id: endpoint.id)
      end.to change(BetterTogether::WebhookEndpoint, :count).by(-1)
    end

    it 'redirects to the index page' do
      delete better_together.webhook_endpoint_path(locale:, id: endpoint.id)
      expect(response).to redirect_to(better_together.webhook_endpoints_path(locale:))
    end
  end

  describe 'POST /host/webhook_endpoints/:id/test', :as_platform_manager do
    let(:endpoint) do
      create(:better_together_webhook_endpoint,
             name: 'Test Action Webhook',
             person: platform_manager.person)
    end

    it 'creates a test webhook delivery' do
      expect do
        post better_together.test_webhook_endpoint_path(locale:, id: endpoint.id)
      end.to change(BetterTogether::WebhookDelivery, :count).by(1)
    end

    it 'creates a delivery with webhook.test event' do
      post better_together.test_webhook_endpoint_path(locale:, id: endpoint.id)
      delivery = BetterTogether::WebhookDelivery.last
      expect(delivery.event).to eq('webhook.test')
      expect(delivery.status).to eq('pending')
    end

    it 'enqueues a WebhookDeliveryJob' do
      expect do
        post better_together.test_webhook_endpoint_path(locale:, id: endpoint.id)
      end.to have_enqueued_job(BetterTogether::WebhookDeliveryJob)
    end

    it 'redirects with a success notice' do
      post better_together.test_webhook_endpoint_path(locale:, id: endpoint.id)
      expect(response).to have_http_status(:found)
      expect(flash[:notice]).to be_present
    end
  end

  describe 'access control' do
    context 'when not authenticated', :unauthenticated do
      it 'denies access to index' do
        get better_together.webhook_endpoints_path(locale:)
        # Routes are behind authenticated constraint, so unauthenticated
        # users receive 404 rather than a redirect to sign in
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
