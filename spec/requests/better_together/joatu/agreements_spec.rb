# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Joatu Agreements API', type: :request do
  describe 'POST /joatu/agreements' do
    it 'creates and rejects an agreement' do
      requestor = create(:better_together_person)
      offeror = create(:better_together_person)
      category = create(:better_together_joatu_category)

      offer = create(:better_together_joatu_offer, creator: offeror)
      offer.categories << category

      request_record = create(:better_together_joatu_request, creator: requestor)
      request_record.categories << category

      post '/en/joatu/agreements', params: { agreement: { offer_id: offer.id, request_id: request_record.id, terms: 'Repair help', value: '20 credits' } }
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('pending')

      post '/en/joatu/agreements/' + json['id'] + '/reject'
      expect(response).to have_http_status(:ok)
      expect(BetterTogether::Joatu::Agreement.find(json['id']).status_rejected?).to be(true)
    end
  end
end
