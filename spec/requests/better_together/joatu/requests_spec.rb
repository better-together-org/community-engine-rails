# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'BetterTogether::Joatu::Requests', :as_user do
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:person) { find_or_create_test_user('user@example.test', 'password12345', :user).person }
  let(:category) { create(:better_together_joatu_category) }
  let(:valid_attributes) do
    { name: 'New Request', description: 'Request description', creator_id: person.id,
      category_ids: [category.id].compact }
  end
  let(:request_record) { create(:joatu_request, creator: person) }

  describe 'routing' do
    it 'routes to #index' do
      get "/#{locale}/exchange/requests"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /index' do
    it 'returns success' do
      get better_together.joatu_requests_path(locale: locale)
      expect(response).to be_successful
    end
  end

  describe 'POST /create' do
    it 'creates a request' do
      expect do
        post better_together.joatu_requests_path(locale: locale), params: { joatu_request: valid_attributes }
      end.to change(BetterTogether::Joatu::Request, :count).by(1)
    end
  end

  describe 'GET /show' do
    it 'returns success' do
      get better_together.joatu_request_path(request_record, locale: locale)
      expect(response).to be_successful
    end
  end

  describe 'PATCH /update' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'updates the request' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      patch better_together.joatu_request_path(request_record, locale: locale),
            params: { joatu_request: { status: 'closed' } }
      expect(response).to redirect_to(
        better_together.edit_joatu_request_path(request_record, locale: locale)
      )
      expect(request_record.reload.status).to eq('closed')
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the request' do
      to_delete = create(:joatu_request, creator: person)
      expect do
        delete better_together.joatu_request_path(to_delete, locale: locale)
      end.to change(BetterTogether::Joatu::Request, :count).by(-1)
    end
  end
  # rubocop:enable Metrics/BlockLength
end
