# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Joatu::ConnectionRequests', :no_auth do
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:network_admin) do
    create(:better_together_user, :confirmed, :network_admin, email: 'network-admin@example.test')
  end
  let(:regular_user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let(:target_platform) { create(:better_together_platform, :community_engine_peer, name: 'Peer Platform') }
  let(:category) { create(:better_together_joatu_category) }
  let(:valid_attributes) do
    {
      type: 'BetterTogether::Joatu::ConnectionRequest',
      name: 'Connect our platforms',
      description: 'Requesting a peer federation link.',
      target_type: 'BetterTogether::Platform',
      target_id: target_platform.id,
      category_ids: [category.id]
    }
  end

  describe 'GET /new' do
    before { sign_in network_admin }

    it 'renders the connection request form with a prefilled platform target' do
      get better_together.new_joatu_request_path(
        locale:,
        type: 'BetterTogether::Joatu::ConnectionRequest',
        target_type: 'BetterTogether::Platform',
        target_id: target_platform.id
      )

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Connection Request')
      expect(response.body).to include(target_platform.name)
      expect(response.body).to include('joatu_request[type]')
      expect(response.body).to include('joatu_request[target_id]')
    end
  end

  describe 'POST /create' do
    context 'as a network admin' do
      before { sign_in network_admin }

      it 'creates a connection request through the generic requests endpoint' do
        expect do
          post better_together.joatu_requests_path(locale:), params: { joatu_request: valid_attributes }
        end.to change(BetterTogether::Joatu::ConnectionRequest, :count).by(1)

        created_request = BetterTogether::Joatu::ConnectionRequest.order(:created_at).last
        expect(created_request.target).to eq(target_platform)
        expect(created_request.creator).to eq(network_admin.person)
      end
    end

    context 'as a regular user' do
      before { sign_in regular_user }

      it 'rejects connection request creation' do
        expect do
          post better_together.joatu_requests_path(locale:), params: { joatu_request: valid_attributes }
        end.not_to change(BetterTogether::Joatu::ConnectionRequest, :count)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
