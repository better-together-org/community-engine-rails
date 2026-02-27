# frozen_string_literal: true

require 'rails_helper'

# Specs for community-scoped webhook management at /c/:community_id/webhook_endpoints
# Community admins (and platform managers) can manage webhooks for their communities.
RSpec.describe 'Community Webhook Endpoints', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let!(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let!(:person) { platform_manager.person }
  let!(:community) { create(:better_together_community) }

  def index_path
    better_together.community_community_webhook_endpoints_path(locale:, community_id: community)
  end

  def new_path
    better_together.new_community_community_webhook_endpoint_path(locale:, community_id: community)
  end

  def show_path(endpoint)
    better_together.community_community_webhook_endpoint_path(locale:, community_id: community, id: endpoint)
  end

  def edit_path(endpoint)
    better_together.edit_community_community_webhook_endpoint_path(locale:, community_id: community, id: endpoint)
  end

  def test_path(endpoint)
    better_together.test_community_community_webhook_endpoint_path(locale:, community_id: community, id: endpoint)
  end

  describe 'GET /c/:community_id/webhook_endpoints (index)' do
    it 'returns 200' do
      get index_path
      expect(response).to have_http_status(:ok)
    end

    context 'with an existing community endpoint' do
      let!(:endpoint) do
        create(:better_together_webhook_endpoint,
               person: person,
               community: community,
               name: 'Community Events Hook')
      end

      it 'displays the endpoint name' do
        get index_path
        expect_html_content('Community Events Hook')
      end

      it 'does not display endpoints from other communities' do
        other_community = create(:better_together_community)
        other_endpoint = create(:better_together_webhook_endpoint,
                                person: person,
                                community: other_community,
                                name: 'Other Community Hook')
        get index_path
        expect(response.body).not_to include(other_endpoint.name)
      end
    end
  end

  describe 'GET /c/:community_id/webhook_endpoints/new' do
    it 'renders the new webhook form' do
      get new_path
      expect(response).to have_http_status(:ok)
    end

    it 'includes required form fields' do
      get new_path
      expect(response.body).to include('webhook_endpoint[url]')
      expect(response.body).to include('webhook_endpoint[name]')
    end
  end

  describe 'POST /c/:community_id/webhook_endpoints (create)' do
    let(:valid_params) do
      {
        webhook_endpoint: {
          name: 'Community Notify',
          url: 'https://hooks.example.com/community',
          events: 'community.created,post.created'
        }
      }
    end

    it 'creates a new webhook endpoint' do
      expect do
        post index_path, params: valid_params
      end.to change(BetterTogether::WebhookEndpoint, :count).by(1)
    end

    it 'assigns the community to the endpoint' do
      post index_path, params: valid_params
      endpoint = BetterTogether::WebhookEndpoint.last
      expect(endpoint.community).to eq(community)
    end

    it 'assigns the current person as owner' do
      post index_path, params: valid_params
      endpoint = BetterTogether::WebhookEndpoint.last
      expect(endpoint.person).to eq(person)
    end

    it 'auto-generates a signing secret' do
      post index_path, params: valid_params
      endpoint = BetterTogether::WebhookEndpoint.last
      expect(endpoint.secret).to be_present
    end

    it 'redirects after successful creation' do
      post index_path, params: valid_params
      expect(response).to have_http_status(:found)
    end

    context 'with invalid params' do
      it 'does not create an endpoint with missing name' do
        expect do
          post index_path, params: { webhook_endpoint: { url: 'https://example.com', name: '' } }
        end.not_to change(BetterTogether::WebhookEndpoint, :count)
      end

      it 'returns unprocessable entity' do
        post index_path, params: { webhook_endpoint: { url: 'not-a-url', name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /c/:community_id/webhook_endpoints/:id (show)' do
    let!(:endpoint) do
      create(:better_together_webhook_endpoint,
             person: person, community: community, name: 'Show Hook')
    end

    it 'renders the show page' do
      get show_path(endpoint)
      expect(response).to have_http_status(:ok)
    end

    it 'displays the endpoint URL' do
      get show_path(endpoint)
      expect_html_content(endpoint.url)
    end
  end

  describe 'GET /c/:community_id/webhook_endpoints/:id/edit' do
    let!(:endpoint) do
      create(:better_together_webhook_endpoint,
             person: person, community: community, name: 'Edit Hook')
    end

    it 'renders the edit form' do
      get edit_path(endpoint)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /c/:community_id/webhook_endpoints/:id (update)' do
    let!(:endpoint) do
      create(:better_together_webhook_endpoint,
             person: person, community: community, name: 'Old Hook Name')
    end

    it 'updates the webhook name' do
      patch show_path(endpoint), params: { webhook_endpoint: { name: 'New Hook Name' } }
      expect(endpoint.reload.name).to eq('New Hook Name')
    end

    it 'redirects after update' do
      patch show_path(endpoint), params: { webhook_endpoint: { name: 'New Hook Name' } }
      expect(response).to have_http_status(:found)
    end
  end

  describe 'DELETE /c/:community_id/webhook_endpoints/:id (destroy)' do
    let!(:endpoint) do
      create(:better_together_webhook_endpoint,
             person: person, community: community, name: 'Delete Hook')
    end

    it 'deletes the endpoint' do
      expect do
        delete show_path(endpoint)
      end.to change(BetterTogether::WebhookEndpoint, :count).by(-1)
    end

    it 'redirects after deletion' do
      delete show_path(endpoint)
      expect(response).to have_http_status(:found)
    end
  end

  describe 'POST /c/:community_id/webhook_endpoints/:id/test' do
    let!(:endpoint) do
      create(:better_together_webhook_endpoint,
             person: person, community: community, name: 'Test Hook')
    end

    it 'queues a test delivery' do
      expect do
        post test_path(endpoint)
      end.to have_enqueued_job(BetterTogether::WebhookDeliveryJob)
    end

    it 'creates a webhook delivery record' do
      expect do
        post test_path(endpoint)
      end.to change(BetterTogether::WebhookDelivery, :count).by(1)
    end

    it 'redirects with a success notice' do
      post test_path(endpoint)
      expect(response).to have_http_status(:found)
    end
  end

  describe 'access control' do
    context 'for unauthenticated users', :unauthenticated do
      it 'blocks unauthenticated index access' do
        get index_path
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
