# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Metrics::SearchQueriesController' do
  let(:locale) { I18n.default_locale }
  let(:capture_service) { instance_double(BetterTogether::Metrics::SearchQueryCaptureService, call: 'test') }

  before do
    allow(BetterTogether::Metrics::SearchQueryCaptureService).to receive(:new).and_return(capture_service)
  end

  # rubocop:todo RSpec/MultipleExpectations
  it 'tracks a search query with valid params' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    expect do
      post better_together.metrics_search_queries_path(locale:), params: {
        query: 'test',
        results_count: 3
      }
    end.to have_enqueued_job(BetterTogether::Metrics::TrackSearchQueryJob).with('test', 3, locale.to_s)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['success']).to be(true)
  end

  it 'hashes the tracked query when the capture service returns a digest' do
    allow(capture_service).to receive(:call)
      .with('Test Query')
      .and_return("sha256:#{Digest::SHA256.hexdigest('test query')}")

    expect do
      post better_together.metrics_search_queries_path(locale:), params: {
        query: 'Test Query',
        results_count: 3
      }
    end.to have_enqueued_job(BetterTogether::Metrics::TrackSearchQueryJob)
      .with("sha256:#{Digest::SHA256.hexdigest('test query')}", 3, locale.to_s)
  end

  it 'does not enqueue when capture returns nil' do
    allow(capture_service).to receive(:call).with('test').and_return(nil)

    expect do
      post better_together.metrics_search_queries_path(locale:), params: {
        query: 'test',
        results_count: 3
      }
    end.not_to have_enqueued_job(BetterTogether::Metrics::TrackSearchQueryJob)
  end

  it 'returns success when capture returns nil' do
    allow(capture_service).to receive(:call).with('test').and_return(nil)

    post better_together.metrics_search_queries_path(locale:), params: {
      query: 'test',
      results_count: 3
    }

    expect(response).to have_http_status(:ok)
  end

  it 'returns 422 for invalid params' do
    post better_together.metrics_search_queries_path(locale:), params: { query: '', results_count: '' }
    expect(response).to have_http_status(:unprocessable_content)
  end
end
