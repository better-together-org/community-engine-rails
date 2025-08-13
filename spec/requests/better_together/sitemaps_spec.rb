# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sitemap', type: :request do
  include BetterTogether::Engine.routes.url_helpers
  include BetterTogether::DeviseSessionHelpers

  let!(:host_platform) { configure_host_platform }

  before do
    host! 'www.example.com'
    Rails.application.routes.default_url_options[:host] = 'www.example.com'
  end

  describe 'GET /sitemap.xml.gz' do
    context 'when a sitemap is attached' do
      it 'redirects to the file' do
        sitemap = BetterTogether::Sitemap.current(host_platform)
        sitemap.file.attach(io: StringIO.new('test'), filename: 'sitemap.xml.gz', content_type: 'application/gzip')

        get sitemap_path

        expect(response).to redirect_to(sitemap.file.url)
      end
    end

    context 'when no sitemap exists' do
      it 'returns not found' do
        BetterTogether::Sitemap.current(host_platform).file.detach

        get sitemap_path

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
