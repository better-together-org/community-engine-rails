# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sitemap' do
  include BetterTogether::Engine.routes.url_helpers
  include BetterTogether::DeviseSessionHelpers

  let!(:host_platform) { configure_host_platform }

  before do
    host! 'www.example.com'
    Rails.application.routes.default_url_options[:host] = 'www.example.com'
    ActiveStorage::Current.url_options = { host: 'www.example.com', protocol: 'http' }

    host_platform.update!(privacy: 'public')

    # Delete any physical sitemap file that might exist from previous test runs
    # to ensure the controller logic is being tested, not the public file middleware
    public_sitemap = Rails.root.join('public', 'sitemap.xml.gz')
    FileUtils.rm_f(public_sitemap)
  end

  describe 'GET /sitemap.xml.gz (index)' do
    context 'when a sitemap index is attached' do
      it 'redirects to the file' do
        sitemap = BetterTogether::Sitemap.current_index(host_platform)
        sitemap.file.attach(
          io: StringIO.new('test index'),
          filename: 'sitemap_index.xml.gz',
          content_type: 'application/gzip'
        )

        get sitemap_index_path

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('sitemap')
        expect(response.location).to include('.xml.gz')
      end
    end

    context 'when no sitemap index exists' do
      it 'returns not found' do
        sitemap = BetterTogether::Sitemap.find_by(platform: host_platform, locale: 'index')
        sitemap&.file&.detach

        get sitemap_index_path

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # rubocop:disable RSpec/NestedGroups
  describe 'GET /:locale/sitemap.xml.gz (locale-specific)' do
    I18n.available_locales.each do |test_locale|
      context "for locale #{test_locale}" do
        context 'when a sitemap is attached' do
          it 'redirects to the file' do
            sitemap = BetterTogether::Sitemap.current(host_platform, test_locale)
            sitemap.file.attach(
              io: StringIO.new("test #{test_locale}"),
              filename: "sitemap_#{test_locale}.xml.gz",
              content_type: 'application/gzip'
            )

            get sitemap_path(locale: test_locale)

            expect(response).to have_http_status(:redirect)
            expect(response.location).to include('sitemap')
            expect(response.location).to include('.xml.gz')
          end
        end

        context 'when no sitemap exists for locale' do
          it 'returns not found' do
            sitemap = BetterTogether::Sitemap.find_by(platform: host_platform, locale: test_locale.to_s)
            sitemap&.file&.detach

            get sitemap_path(locale: test_locale)

            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end

    context 'with invalid locale' do
      it 'raises routing error due to locale constraint' do
        expect do
          get sitemap_path(locale: 'invalid')
        end.to raise_error(ActionController::UrlGenerationError, /possible unmatched constraints/)
      end
    end

    context 'with missing locale parameter' do
      it 'routes to index action instead' do
        # When no locale is provided, it matches the index route (/sitemap.xml.gz)
        get '/sitemap.xml.gz'
        expect(response).to have_http_status(:not_found) # Index doesn't exist in this test
      end
    end
    # rubocop:enable RSpec/NestedGroups
  end
end
