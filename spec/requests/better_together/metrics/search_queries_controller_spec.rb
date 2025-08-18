# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::SearchQueriesController', type: :request do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  it 'tracks a search query with valid params' do
    post better_together.metrics_search_queries_path(locale:), params: {
      query: 'test',
      results_count: 3
    }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['success']).to eq(true)
  end

  it 'returns 422 for invalid params' do
    post better_together.metrics_search_queries_path(locale:), params: { query: '', results_count: '' }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
