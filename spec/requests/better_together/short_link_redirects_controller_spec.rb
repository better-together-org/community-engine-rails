# frozen_string_literal: true

require 'rails_helper'

# Controller-focused request spec for BetterTogether::ShortLinkRedirectsController.
# Complements spec/requests/better_together/short_link_redirects_spec.rb which
# covers the core redirect/404 behaviour.  This file focuses on the response
# headers and the visit-recording side-effects in detail.
RSpec.describe BetterTogether::ShortLinkRedirectsController do
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:target_url)    { 'https://example.com/destination' }
  let!(:short_link) do
    create(:better_together_short_link,
           platform: host_platform,
           target_url: target_url,
           status: 'active',
           expires_at: nil)
  end

  describe 'GET /s/:code' do
    context 'with an active, unexpired link' do
      it 'redirects to the target URL with HTTP 302' do
        get better_together.short_link_redirect_path(code: short_link.code)
        expect(response).to redirect_to(target_url)
        expect(response).to have_http_status(:found)
      end

      it 'sets the X-Robots-Tag: noindex header to suppress search-engine indexing' do
        get better_together.short_link_redirect_path(code: short_link.code)
        expect(response.headers['X-Robots-Tag']).to eq('noindex')
      end

      it 'enqueues BetterTogether::Metrics::TrackShortLinkVisitJob with a payload hash' do
        expect do
          get better_together.short_link_redirect_path(code: short_link.code)
        end.to have_enqueued_job(BetterTogether::Metrics::TrackShortLinkVisitJob)
          .with(hash_including('short_link_id' => short_link.id))
      end

      it 'increments click_count by 1' do
        expect do
          get better_together.short_link_redirect_path(code: short_link.code)
        end.to change { short_link.reload.click_count }.by(1)
      end
    end

    context 'with an inactive link' do
      let!(:short_link) do
        create(:better_together_short_link, :inactive,
               platform: host_platform,
               target_url: target_url)
      end

      it 'returns 404' do
        get better_together.short_link_redirect_path(code: short_link.code)
        expect(response).to have_http_status(:not_found)
      end

      it 'does not enqueue the visit tracking job' do
        expect do
          get better_together.short_link_redirect_path(code: short_link.code)
        end.not_to have_enqueued_job(BetterTogether::Metrics::TrackShortLinkVisitJob)
      end
    end

    context 'with an expired link (status = expired)' do
      let!(:short_link) do
        create(:better_together_short_link, :expired,
               platform: host_platform,
               target_url: target_url)
      end

      it 'returns 404' do
        get better_together.short_link_redirect_path(code: short_link.code)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with a code that does not exist' do
      it 'returns 404' do
        get better_together.short_link_redirect_path(code: 'xxxxxx')
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
