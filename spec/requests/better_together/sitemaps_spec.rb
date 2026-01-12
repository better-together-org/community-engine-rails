# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sitemap', type: :request do
  include BetterTogether::Engine.routes.url_helpers
  include BetterTogether::DeviseSessionHelpers

  let!(:host_platform) { configure_host_platform }

  before do
    host! 'www.example.com'
    Rails.application.routes.default_url_options[:host] = 'www.example.com'
    ActiveStorage::Current.url_options = { host: 'www.example.com', protocol: 'http' }

    # Delete any physical sitemap file that might exist from previous test runs
    # to ensure the controller logic is being tested, not the public file middleware
    public_sitemap = Rails.root.join('public', 'sitemap.xml.gz')
    File.delete(public_sitemap) if File.exist?(public_sitemap)
  end

  describe 'GET /sitemap.xml.gz' do
    context 'when a sitemap is attached' do
      it 'redirects to the file' do
        sitemap = BetterTogether::Sitemap.current(host_platform)
        sitemap.file.attach(io: StringIO.new('test'), filename: 'sitemap.xml.gz', content_type: 'application/gzip')

        get sitemap_path

        # The controller redirects to the blob URL
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('sitemap.xml.gz')
      end
    end

    context 'when no sitemap exists' do
      it 'returns not found' do
        sitemap = BetterTogether::Sitemap.current(host_platform)
        sitemap.file.detach if sitemap.file.attached?

        get sitemap_path

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
