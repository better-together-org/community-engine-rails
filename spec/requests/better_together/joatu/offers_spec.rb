# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Joatu Offers API', type: :request do
  let(:person) { create(:better_together_person) }

  describe 'POST /joatu/offers' do
    it 'creates an offer' do
      post '/en/joatu/offers', params: { offer: { name: 'Lawn mowing', description: 'Will mow your lawn', creator_id: person.id } }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['name']).to eq('Lawn mowing')
    end

    it 'returns errors for invalid input' do
      post '/en/joatu/offers', params: { offer: { description: 'No name', creator_id: person.id } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
