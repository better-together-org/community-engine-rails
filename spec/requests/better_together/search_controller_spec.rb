# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::SearchController', :as_user do
  let(:locale) { I18n.default_locale }
  let(:backend) { instance_double(BetterTogether::Search::ElasticsearchBackend, backend_key: :elasticsearch) }
  let(:capture_service) { instance_double(BetterTogether::Metrics::SearchQueryCaptureService, call: captured_query) }
  let(:captured_query) { 'test query' }
  let!(:host_platform) { configure_host_platform }

  before do
    allow(BetterTogether::Search).to receive(:backend).and_return(backend)
    allow(BetterTogether::Metrics::SearchQueryCaptureService).to receive(:new).and_return(capture_service)
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
          .with(captured_query, 0, locale.to_s, host_platform.id, true)
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
          locale: locale.to_s,
          platform_id: host_platform.id,
          logged_in: true
        )
      end

      it 'hashes tracked queries when the capture service returns a digest' do
        allow(capture_service).to receive(:call)
          .with('Test Query')
          .and_return("sha256:#{Digest::SHA256.hexdigest('test query')}")

        expect do
          get better_together.search_path(locale:), params: { q: 'Test Query' }
        end.to have_enqueued_job(BetterTogether::Metrics::TrackSearchQueryJob)
          .with("sha256:#{Digest::SHA256.hexdigest('test query')}", 0, locale.to_s, host_platform.id, true)
      end

      it 'does not enqueue search analytics when capture returns nil' do
        allow(capture_service).to receive(:call).with('test query').and_return(nil)

        expect do
          get better_together.search_path(locale:), params: { q: 'test query' }
        end.not_to have_enqueued_job(BetterTogether::Metrics::TrackSearchQueryJob)
      end

      it 'filters private linked seed models out of the global search set' do
        # PersonLinkedSeed.global_searchable? returns false so Registry excludes it from
        # global_search_models. The registry_spec covers this at unit level; here we confirm
        # the search endpoint still returns 200 and the Registry reflects the exclusion.
        expect(BetterTogether::Search::Registry.global_search_models)
          .not_to include(BetterTogether::PersonLinkedSeed)

        get better_together.search_path(locale:), params: { q: 'test query' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when query parameter is blank' do
      it 'does not enqueue a TrackSearchQueryJob' do
        expect do
          get better_together.search_path(locale:), params: { q: '' }
        end.not_to have_enqueued_job(BetterTogether::Metrics::TrackSearchQueryJob)
      end
    end

    context 'when the backend returns mixed-visibility records', :no_auth do
      let!(:public_post) do
        create(
          :better_together_post,
          title: 'Borgberry Public Post',
          privacy: 'public',
          published_at: 1.day.ago
        )
      end

      let!(:private_post) do
        create(
          :better_together_post,
          title: 'Borgberry Private Post',
          privacy: 'private',
          published_at: 1.day.ago
        )
      end

      let!(:scheduled_page) do
        create(
          :better_together_page,
          title: 'Borgberry Scheduled Page',
          privacy: 'public',
          published_at: 1.day.from_now
        )
      end

      before do
        allow(backend).to receive(:search).and_return(
          BetterTogether::Search::SearchResult.new(
            records: [public_post, private_post, scheduled_page],
            suggestions: ['borgberry private post'],
            status: :ok,
            backend: :elasticsearch
          )
        )
      end

      it 'renders only records visible to the current visitor and suppresses suggestions' do
        get better_together.search_path(locale:), params: { q: 'borgberry' }

        visible_titles = assigns(:results).map { |result| result.try(:title) || result.try(:name) }

        expect(response).to have_http_status(:ok)
        expect(visible_titles).to include('Borgberry Public Post')
        expect(visible_titles).not_to include('Borgberry Private Post')
        expect(visible_titles).not_to include('Borgberry Scheduled Page')
        expect(response.body).not_to include('Did you mean?')
        expect(response.body).not_to include('borgberry private post')
      end
    end

    context 'when the backend returns records that require authentication', :no_auth do
      let!(:offer) { create(:better_together_joatu_offer, name: 'Borgberry Mutual Aid Offer') }

      before do
        allow(backend).to receive(:search).and_return(
          BetterTogether::Search::SearchResult.new(
            records: [offer],
            suggestions: [],
            status: :ok,
            backend: :pg_search
          )
        )
      end

      it 'filters records whose policy denies guest access' do
        get better_together.search_path(locale:), params: { q: 'borgberry' }

        visible_titles = assigns(:results).map { |result| result.try(:title) || result.try(:name) }

        expect(response).to have_http_status(:ok)
        expect(visible_titles).not_to include('Borgberry Mutual Aid Offer')
      end
    end

    context 'when the backend returns the current user private content', :as_user do
      let(:user) { BetterTogether::User.find_by!(email: 'user@example.test') }
      let!(:own_private_post) do
        create(
          :better_together_post,
          title: 'My Borgberry Draft',
          privacy: 'private',
          published_at: 1.day.ago,
          creator: user.person,
          author: user.person
        )
      end

      let!(:other_private_post) do
        create(
          :better_together_post,
          title: 'Someone Else Borgberry Draft',
          privacy: 'private',
          published_at: 1.day.ago
        )
      end

      before do
        allow(backend).to receive(:search).and_return(
          BetterTogether::Search::SearchResult.new(
            records: [own_private_post, other_private_post],
            suggestions: ['someone else borgberry draft'],
            status: :ok,
            backend: :elasticsearch
          )
        )
      end

      it 'keeps authorized private records while filtering unauthorized ones' do
        get better_together.search_path(locale:), params: { q: 'borgberry' }

        visible_titles = assigns(:results).map { |result| result.try(:title) || result.try(:name) }

        expect(response).to have_http_status(:ok)
        expect(visible_titles).to include('My Borgberry Draft')
        expect(visible_titles).not_to include('Someone Else Borgberry Draft')
        expect(response.body).not_to include('Did you mean?')
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
        allow(capture_service).to receive(:call).with('test').and_return('test')
      end

      it 'handles the error gracefully and still tracks metrics' do
        expect do
          get better_together.search_path(locale:), params: { q: 'test' }
        end.to have_enqueued_job(BetterTogether::Metrics::TrackSearchQueryJob)
          .with('test', 0, locale.to_s, host_platform.id, true)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
