# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ShortLinkRedirects' do
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:target) { 'https://example.com/destination' }
  let!(:short_link) do
    create(:better_together_short_link,
           platform: host_platform,
           target_url: target,
           status: 'active',
           expires_at: nil)
  end

  describe 'GET /s/:code' do
    context 'when the link is active and unexpired' do
      it 'redirects to the target URL' do
        get better_together.short_link_redirect_path(code: short_link.code)

        expect(response).to redirect_to(target)
        expect(response).to have_http_status(:found)
      end

      it 'sets X-Robots-Tag: noindex' do
        get better_together.short_link_redirect_path(code: short_link.code)

        expect(response.headers['X-Robots-Tag']).to eq('noindex')
      end

      it 'enqueues the visit tracking job' do
        expect do
          get better_together.short_link_redirect_path(code: short_link.code)
        end.to have_enqueued_job(BetterTogether::Metrics::TrackShortLinkVisitJob)
      end

      it 'increments click_count' do
        expect do
          get better_together.short_link_redirect_path(code: short_link.code)
        end.to change { short_link.reload.click_count }.by(1)
      end
    end

    context 'when the link is inactive' do
      let!(:short_link) do
        create(:better_together_short_link, :inactive,
               platform: host_platform,
               target_url: target)
      end

      it 'returns 404' do
        get better_together.short_link_redirect_path(code: short_link.code)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the link is expired' do
      let!(:short_link) do
        create(:better_together_short_link, :expired,
               platform: host_platform,
               target_url: target)
      end

      it 'returns 404' do
        get better_together.short_link_redirect_path(code: short_link.code)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the code does not exist' do
      it 'returns 404' do
        get better_together.short_link_redirect_path(code: 'zzzzzz')

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
