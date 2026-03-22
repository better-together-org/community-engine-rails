# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::SearchController', :as_user do
  let(:locale) { I18n.default_locale }
  let(:backend) { instance_double(BetterTogether::Search::ElasticsearchBackend, backend_key: :elasticsearch) }

  before do
    allow(BetterTogether::Search).to receive(:backend).and_return(backend)
  end

  describe 'GET /search' do
    it 'renders search results page' do
      allow(backend).to receive(:search).and_return(
        BetterTogether::Search::SearchResult.new(
          records: [],
          suggestions: [],
          status: :ok,
          backend: :elasticsearch
        )
      )

      get better_together.search_path(locale:), params: { q: 'test' }
      expect(response).to have_http_status(:ok)
    end

    context 'when searching with a query' do
      before do
        allow(backend).to receive(:search).and_return(
          BetterTogether::Search::SearchResult.new(
            records: [],
            suggestions: [],
            status: :ok,
            backend: :elasticsearch
          )
        )
      end

      it 'enqueues a TrackSearchQueryJob' do
        expect do
          get better_together.search_path(locale:), params: { q: 'test query' }
        end.to have_enqueued_job(BetterTogether::Metrics::TrackSearchQueryJob)
          .with('test query', 0, locale.to_s)
      end

      it 'creates a search query metric when job is performed' do
        expect do
          perform_enqueued_jobs do
            get better_together.search_path(locale:), params: { q: 'test query' }
          end
        end.to change(BetterTogether::Metrics::SearchQuery, :count).by(1)

        metric = BetterTogether::Metrics::SearchQuery.last
        expect(metric).to have_attributes(
          query: 'test query',
          results_count: 0,
          locale: locale.to_s
        )
      end
    end

    context 'when query parameter is blank' do
      it 'does not enqueue a TrackSearchQueryJob' do
        expect do
          get better_together.search_path(locale:), params: { q: '' }
        end.not_to have_enqueued_job(BetterTogether::Metrics::TrackSearchQueryJob)
      end
    end

    context 'when Elasticsearch raises an error' do
      before do
        allow(backend).to receive(:search).and_return(
          BetterTogether::Search::SearchResult.new(
            records: [],
            suggestions: [],
            status: :unreachable,
            backend: :elasticsearch,
            error: 'StandardError: ES Error'
          )
        )
      end

      it 'handles the error gracefully and still tracks metrics' do
        expect do
          get better_together.search_path(locale:), params: { q: 'test' }
        end.to have_enqueued_job(BetterTogether::Metrics::TrackSearchQueryJob)
          .with('test', 0, locale.to_s)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
