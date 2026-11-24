# frozen_string_literal: true

require 'rails_helper'

# Admin UI for a platform's redirects: /host/platforms/:platform_id/redirects
RSpec.describe 'BetterTogether::RedirectsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }

  it 'lists redirects with their status and visits' do
    create(:better_together_redirect, platform:, from_path: '/legacy.html', to_path: '/en/legacy')

    get platform_redirects_path(platform, locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('legacy.html', 'redirects-table')
  end

  it 'filters the list by old path' do
    create(:better_together_redirect, platform:, from_path: '/keep-me', to_path: '/en/a')
    create(:better_together_redirect, platform:, from_path: '/other', to_path: '/en/b')

    get platform_redirects_path(platform, locale:, q: 'keep')

    expect(response.body).to include('/keep-me')
    expect(response.body).not_to include('/other')
  end

  it 'creates, updates and deletes a redirect' do
    expect do
      post platform_redirects_path(platform, locale:),
           params: { redirect: { from_path: '/created', to_path: '/en/created', status: 301 } }
    end.to change(platform.redirects, :count).by(1)
    redirect = platform.redirects.find_by!(from_path: '/created')

    patch platform_redirect_path(platform, redirect, locale:), params: { redirect: { status: 302 } }
    expect(redirect.reload.status).to eq(302)

    expect { delete platform_redirect_path(platform, redirect, locale:) }
      .to change(platform.redirects, :count).by(-1)
  end

  it 'rejects an invalid destination with the form re-rendered' do
    post platform_redirects_path(platform, locale:),
         params: { redirect: { from_path: '/bad', to_path: 'javascript:alert(1)', status: 301 } }

    expect(response).to have_http_status(:unprocessable_content)
  end

  describe 'bulk import' do
    let(:rows) { "/a.html,/en/a\n# comment\n/b.pdf,/en/f/b,308\n" }

    it 'previews without saving' do
      expect { post import_platform_redirects_path(platform, locale:), params: { rows: } }
        .not_to change(platform.redirects, :count)

      expect(response.body).to include('redirects-import-report')
    end

    it 'saves when the import button is used' do
      expect { post import_platform_redirects_path(platform, locale:), params: { rows:, commit_import: 'Import' } }
        .to change(platform.redirects, :count).by(2)
    end
  end
end
