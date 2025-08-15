# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'BetterTogether::Joatu::Requests', type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:person) { user.person }
  let(:valid_attributes) { { name: 'New Request', description: 'Request description', creator_id: person.id } }
  let(:request_record) { create(:joatu_request) }

  before { login(user) }

  describe 'routing' do
    it 'routes to #index' do
      expect(get: "/#{I18n.locale}/joatu/requests").to route_to(
        'better_together/joatu/requests#index',
        locale: I18n.locale.to_s
      )
    end
  end

  describe 'GET /index' do
    it 'returns success' do
      get better_together.joatu_requests_path(locale: I18n.locale)
      expect(response).to be_successful
    end
  end

  describe 'POST /create' do
    it 'creates a request' do
      expect do
        post better_together.joatu_requests_path(locale: I18n.locale), params: { request: valid_attributes }
      end.to change(BetterTogether::Joatu::Request, :count).by(1)
    end
  end

  describe 'GET /show' do
    it 'returns success' do
      get better_together.joatu_request_path(request_record, locale: I18n.locale)
      expect(response).to be_successful
    end
  end

  describe 'PATCH /update' do
    it 'updates the request' do
      patch better_together.joatu_request_path(request_record, locale: I18n.locale),
            params: { request: { status: 'closed' } }
      expect(response).to redirect_to(
        better_together.joatu_request_path(request_record, locale: I18n.locale)
      )
      expect(request_record.reload.status).to eq('closed')
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the request' do
      to_delete = create(:joatu_request)
      expect do
        delete better_together.joatu_request_path(to_delete, locale: I18n.locale)
      end.to change(BetterTogether::Joatu::Request, :count).by(-1)
    end
  end
  # rubocop:enable Metrics/BlockLength
end
