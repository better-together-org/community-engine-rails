# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Joatu matchmaking', type: :request do
  let(:requestor) { create(:better_together_person) }
  let(:offeror) { create(:better_together_person) }
  let(:category) { create(:better_together_joatu_category) }
  let!(:offer) do
    create(:better_together_joatu_offer, creator: offeror).tap do |o|
      o.categories << category
    end
  end
  let!(:request_model) do
    create(:better_together_joatu_request, creator: requestor).tap do |r|
      r.categories << category
    end
  end
  let(:locale) { I18n.default_locale }

  describe 'GET /joatu/requests/:id/matches' do
    it 'renders matching offers' do
      get "/#{locale}/joatu/requests/#{request_model.id}/matches"
      expect(response.body).to include(offer.name)
    end
  end

  describe 'POST /joatu/requests/:request_id/agreements' do
    it 'creates an agreement and accepts it' do
      post "/#{locale}/joatu/requests/#{request_model.id}/agreements", params: { offer_id: offer.id }
      agreement = BetterTogether::Joatu::Agreement.last
      expect(agreement.offer).to eq(offer)

      post "/#{locale}/joatu/agreements/#{agreement.id}/accept"
      expect(agreement.reload.status_accepted?).to be true
    end

    it 'rejects an agreement' do
      agreement = BetterTogether::Joatu::Agreement.create!(offer:, request: request_model, terms: '', value: '')
      post "/#{locale}/joatu/agreements/#{agreement.id}/reject"
      expect(agreement.reload.status_rejected?).to be true
    end
  end
end
