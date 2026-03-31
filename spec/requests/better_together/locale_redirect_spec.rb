# frozen_string_literal: true

require 'rails_helper'

# @hermetic
# Tests for the catch-all locale redirect route.
# Regression coverage for URI::InvalidURIError on non-default locale + accented slug URLs.
# Root cause: the constraint only checked I18n.locale (the default, :en), so /fr/... URLs
# slipped through and were double-prefixed to /en/fr/à-propos-de-nous. ActionDispatch's
# Redirect#build_response then called URI.parse on the decoded URL and raised.
RSpec.describe 'Locale redirect catch-all' do
  let(:default_locale) { I18n.default_locale }

  describe 'paths with a valid locale prefix' do
    it 'does NOT redirect English-prefixed paths' do
      get '/en/some-page'
      expect(response).not_to have_http_status(:redirect)
    end

    it 'does NOT redirect French-prefixed paths (regression: was redirecting to /en/fr/...)' do
      get '/fr/some-page'
      # Must not redirect; should either render or 404 but never issue a redirect
      expect(response).not_to have_http_status(:moved_permanently)
      expect(response).not_to have_http_status(:found)
    end

    it 'does NOT raise URI::InvalidURIError for French paths with accented slugs' do
      expect do
        get '/fr/%C3%A0-propos-de-nous'
      end.not_to raise_error
    end

    it 'does NOT redirect French paths with accented slugs to a double-locale URL' do
      get '/fr/%C3%A0-propos-de-nous'
      if response.redirect?
        # If somehow a redirect fires, it must not double-prefix the locale
        expect(response.location).not_to include('/en/fr/')
      end
    end
  end

  describe 'paths without any locale prefix' do
    it 'redirects bare paths to the default locale' do
      get '/some-page'
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("/#{default_locale}/some-page")
    end

    it 'percent-encodes non-ASCII characters in the redirected path' do
      get '/caf%C3%A9'
      expect(response).to have_http_status(:redirect)
      # The redirect location must be valid ASCII (no raw non-ASCII chars)
      expect(response.location).to match(%r{/#{default_locale}/})
      expect(response.location.encoding).to eq(Encoding::UTF_8)
      expect(response.location).not_to match(/[^\x00-\x7F]/)
    end
  end
end
