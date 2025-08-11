# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Joatu Requests API', type: :request do
  let(:person) { create(:better_together_person) }

  describe 'POST /joatu/requests' do
    it 'creates a request' do
      post '/en/joatu/requests', params: { request: { name: 'Need a drill', description: 'Borrow a drill for weekend', creator_id: person.id } }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['name']).to eq('Need a drill')
    end

    it 'returns errors for invalid input' do
      post '/en/joatu/requests', params: { request: { description: 'Missing name', creator_id: person.id } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
