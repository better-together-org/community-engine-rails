# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'BetterTogether::Joatu::Offers', type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:person) { user.person }
  let(:valid_attributes) { { name: 'New Offer', description: 'Offer description', creator_id: person.id } }
  let(:offer) { create(:joatu_offer) }

  before { login(user) }

  describe 'routing' do
    it 'routes to #index' do
      expect(get: "/#{I18n.locale}/joatu/offers").to route_to(
        'better_together/joatu/offers#index',
        locale: I18n.locale.to_s
      )
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
        post better_together.joatu_offers_path(locale: I18n.locale), params: { offer: valid_attributes }
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
    it 'updates the offer' do
      patch better_together.joatu_offer_path(offer, locale: I18n.locale),
            params: { offer: { status: 'closed' } }
      expect(response).to redirect_to(
        better_together.joatu_offer_path(offer, locale: I18n.locale)
      )
      expect(offer.reload.status).to eq('closed')
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the offer' do
      offer_to_delete = create(:joatu_offer)
      expect do
        delete better_together.joatu_offer_path(offer_to_delete, locale: I18n.locale)
      end.to change(BetterTogether::Joatu::Offer, :count).by(-1)
    end
  end
  # rubocop:enable Metrics/BlockLength
end
