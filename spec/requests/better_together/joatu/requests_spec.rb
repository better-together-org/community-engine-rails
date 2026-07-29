# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'BetterTogether::Joatu::Requests', :as_user do
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:person) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user).person }
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
      request_record
      get better_together.joatu_requests_path(locale: locale)
      expect(response).to be_successful
    end
  end

  describe 'POST /create' do
    it 'creates a request' do
      created_request = nil

      expect do
        post better_together.joatu_requests_path(locale: locale), params: { joatu_request: valid_attributes }
        created_request = BetterTogether::Joatu::Request.order(:created_at).last
      end.to change(BetterTogether::Joatu::Request, :count).by(1)

      expect(response).to redirect_to(
        better_together.joatu_request_path(created_request, locale:)
      )
      expect(created_request.creator).to eq(person)
      expect(created_request.categories).to contain_exactly(category)
    end

    it 'renders new when create params are invalid', :aggregate_failures do
      expect do
        post better_together.joatu_requests_path(locale: locale), params: {
          joatu_request: valid_attributes.merge(name: '', description: '')
        }
      end.not_to change(BetterTogether::Joatu::Request, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /show' do
    it 'returns success' do
      get better_together.joatu_request_path(request_record, locale: locale)
      expect(response).to be_successful
    end

    it 'renders the show page for a MembershipRequest with a nil creator (unauthenticated submission)', :as_platform_manager do
      membership_request = create(:membership_request)
      expect(membership_request.creator).to be_nil

      get better_together.joatu_request_path(membership_request, locale: locale)
      expect(response).to be_successful
      expect(response.body).to include('Anonymous requester')
    end
  end

  describe 'PATCH /update' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'updates the request' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      patch better_together.joatu_request_path(request_record, locale: locale),
            params: { joatu_request: { status: 'closed' } }
      expect(response).to redirect_to(
        better_together.edit_joatu_request_path(request_record, locale: locale)
      )
      expect(request_record.reload.status).to eq('closed')
    end

    it 'renders edit when update params are invalid', :aggregate_failures do
      patch better_together.joatu_request_path(request_record, locale: locale),
            params: { joatu_request: { name: '', description: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(request_record.reload.name).not_to be_blank
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

  describe 'GET /respond_with_offer' do
    it 'redirects to a prefilled offer form for the request' do
      get "/#{locale}/exchange/requests/#{request_record.id}/respond_with_offer"

      expect(response).to redirect_to(
        better_together.new_joatu_offer_path(
          locale:,
          source_type: 'BetterTogether::Joatu::Request',
          source_id: request_record.id
        )
      )
    end
  end

  context 'as guest (unauthenticated)', :no_auth do
    let(:public_request) do
      create(:joatu_request).tap { |r| r.update_column(:privacy, 'public') }
    end
    let(:private_request) { create(:joatu_request) }

    it 'allows browsing the request index without signing in' do
      get better_together.joatu_requests_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'allows viewing a public request without signing in' do
      get better_together.joatu_request_path(public_request, locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'redirects to sign-in when viewing a private request' do
      get better_together.joatu_request_path(private_request, locale:)
      expect(response).to redirect_to(new_user_session_path(locale: I18n.locale))
    end
  end
  # rubocop:enable Metrics/BlockLength
end
