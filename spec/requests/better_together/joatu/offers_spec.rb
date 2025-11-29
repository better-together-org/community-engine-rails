# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'BetterTogether::Joatu::Offers', :as_user do
  let(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let(:person) { user.person }
  let(:category) { create(:better_together_joatu_category) }
  let(:valid_attributes) do
    { name: 'New Offer', description: 'Offer description', creator_id: person.id, category_ids: [category.id].compact }
  end
  let(:offer) { create(:joatu_offer, creator: person) }

  describe 'routing' do
    it 'routes to #index' do
      get "/#{I18n.locale}/exchange/offers"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /index' do
    it 'returns success' do
      get better_together.joatu_offers_path(locale: I18n.locale)
      expect(response).to be_successful
    end
  end

  describe 'POST /create' do
    it 'creates an offer' do
      expect do
        post better_together.joatu_offers_path(locale: I18n.locale), params: { joatu_offer: valid_attributes }
      end.to change(BetterTogether::Joatu::Offer, :count).by(1)
    end
  end

  describe 'GET /show' do
    it 'returns success' do
      get better_together.joatu_offer_path(offer, locale: I18n.locale)
      expect(response).to be_successful
    end
  end

  describe 'PATCH /update' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'updates the offer' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      patch better_together.joatu_offer_path(offer, locale: I18n.locale),
            params: { joatu_offer: { status: 'closed' } }
      expect(response).to redirect_to(
        better_together.edit_joatu_offer_path(offer, locale: I18n.locale)
      )
      expect(offer.reload.status).to eq('closed')
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the offer' do
      offer_to_delete = create(:joatu_offer, creator: person)
      expect do
        delete better_together.joatu_offer_path(offer_to_delete, locale: I18n.locale)
      end.to change(BetterTogether::Joatu::Offer, :count).by(-1)
    end
  end
  # rubocop:enable Metrics/BlockLength
end
