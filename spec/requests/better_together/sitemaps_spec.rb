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
  end

  def attach(record, body)
    record.file.attach(io: StringIO.new(body), filename: 'sitemap.xml.gz', content_type: 'application/gzip')
    record
  end

  describe 'GET /sitemap.xml.gz (index)' do
    it 'redirects to the attached index file' do
      sitemap = attach(BetterTogether::Sitemap.current_index(host_platform), 'test index')

      get sitemap_index_path

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include(
        Rails.application.routes.url_helpers.rails_storage_proxy_path(sitemap.file, only_path: true)
      )
    end

    it 'returns not found when no index exists' do
      get sitemap_index_path

      expect(response).to have_http_status(:not_found)
    end
  end

  # rubocop:disable RSpec/NestedGroups
  describe 'GET /:locale/sitemap.xml.gz (locale-specific)' do
    I18n.available_locales.each do |test_locale|
      context "for locale #{test_locale}" do
        it 'redirects to the attached file' do
          sitemap = attach(BetterTogether::Sitemap.current(host_platform, test_locale), "test #{test_locale}")

          get sitemap_path(locale: test_locale)

          expect(response).to have_http_status(:redirect)
          expect(response.location).to include(
            Rails.application.routes.url_helpers.rails_storage_proxy_path(sitemap.file, only_path: true)
          )
        end

        it 'returns not found when no sitemap exists for the locale' do
          get sitemap_path(locale: test_locale)

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'with invalid locale' do
      it 'raises routing error due to locale constraint' do
        expect { get sitemap_path(locale: 'invalid') }
          .to raise_error(ActionController::UrlGenerationError, /possible unmatched constraints/)
      end
    end

    context 'with missing locale parameter' do
      it 'routes to the index action instead' do
        get '/sitemap.xml.gz'
        expect(response).to have_http_status(:not_found)
      end
    end
  end
  # rubocop:enable RSpec/NestedGroups

  describe 'multi-platform isolation' do
    let!(:tenant_platform) do
      create(:better_together_platform, :public, host: false, external: false,
                                                 host_url: 'https://tenant.example.test')
    end

    before do
      attach(BetterTogether::Sitemap.current_index(host_platform), 'host index')
      attach(BetterTogether::Sitemap.current_index(tenant_platform), 'tenant index')
    end

    it "serves the tenant's own sitemap when reached on the tenant domain" do
      host! 'tenant.example.test'

      get sitemap_index_path

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include(
        Rails.application.routes.url_helpers.rails_storage_proxy_path(
          BetterTogether::Sitemap.current_index(tenant_platform).file, only_path: true
        )
      )
    end

    it 'never serves another platform sitemap for the host domain' do
      get sitemap_index_path

      expect(response.location).not_to include(
        Rails.application.routes.url_helpers.rails_storage_proxy_path(
          BetterTogether::Sitemap.current_index(tenant_platform).file, only_path: true
        )
      )
    end
  end

  describe 'non-public platform' do
    before { host_platform.update!(privacy: 'private') }

    it 'returns 404 rather than redirecting to login' do
      attach(BetterTogether::Sitemap.current_index(host_platform), 'x')

      get sitemap_index_path

      expect(response).to have_http_status(:not_found)
    end
  end
end
