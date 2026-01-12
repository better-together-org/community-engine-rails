# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::SearchController', :as_user do
  let(:locale) { I18n.default_locale }

  before do
    # Stub Searchable to return an empty array to avoid ES model issues
    allow(BetterTogether::Searchable).to receive(:included_in_models).and_return([])
  end

  describe 'GET /search' do
    it 'renders search results page' do
      get better_together.search_path(locale:), params: { q: 'test' }
      expect(response).to have_http_status(:ok)
    end

    context 'when searching with a query' do
      before do
        # Stub Elasticsearch to avoid needing a running ES instance
        allow(Elasticsearch::Model).to receive(:search).and_return(
          double(
            records: double(to_a: []),
            response: { 'suggest' => { 'suggestions' => [] } }
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
        allow(Elasticsearch::Model).to receive(:search).and_raise(StandardError, 'ES Error')
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
