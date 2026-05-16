# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ShortLinks#ensure' do
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:locale) { I18n.default_locale }
  let!(:page) do
    create(:better_together_page, platform: host_platform, privacy: 'public',
                                  published_at: 1.day.ago)
  end
  let(:ensure_path) do
    better_together.ensure_content_short_link_path(locale:)
  end

  def ensure_params(linkable = page)
    { linkable_type: linkable.class.name, linkable_id: linkable.id }
  end

  describe 'POST /short_links/ensure' do
    context 'as a guest for public content' do
      it 'returns a turbo-stream response' do
        post ensure_path, params: ensure_params

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to include('turbo-stream')
      end

      it 'targets the correct turbo frame' do
        post ensure_path, params: ensure_params

        expect(response.body).to include("sl-#{ActionView::RecordIdentifier.dom_id(page)}")
      end

      it 'is idempotent — second call returns existing link without creating a duplicate' do
        post ensure_path, params: ensure_params
        expect do
          post ensure_path, params: ensure_params
        end.not_to change(BetterTogether::ShortLink, :count)
      end
    end

    context 'as a guest for unpublished/private content' do
      let!(:private_page) do
        create(:better_together_page, platform: host_platform, privacy: 'private',
                                      published_at: nil)
      end

      it 'is not accessible' do
        post ensure_path, params: ensure_params(private_page)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with an invalid linkable_type' do
      it 'returns 400 Bad Request' do
        post ensure_path, params: { linkable_type: 'String', linkable_id: '1' }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with a linkable_id from a different platform' do
      let(:other_platform) { create(:better_together_platform) }
      let!(:other_page) do
        create(:better_together_page, platform: other_platform, privacy: 'public',
                                      published_at: 1.day.ago)
      end

      it 'returns 404' do
        post ensure_path, params: ensure_params(other_page)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
