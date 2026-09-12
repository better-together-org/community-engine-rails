# frozen_string_literal: true

require 'rails_helper'

# Regression coverage: ApplicationController#set_locale previously assigned params[:locale]
# straight to I18n.locale= with no validation, so a malformed/malicious locale param (a
# blind-SQLi scanner probe was observed hitting /sitemap.xml.gz in production) raised
# I18n::InvalidLocale as an unhandled 500 before any controller logic ran. /sitemap.xml.gz
# is used here deliberately: SitemapsController#index takes no locale path segment, so
# params[:locale] can only come from the query string — the exact production attack shape.
RSpec.describe 'Locale handling in ApplicationController#set_locale' do
  let(:sqli_probe) { "' AND (SELECT 1 FROM(SELECT NAME_CONST(USER(),1),NAME_CONST(USER(),1))a)--" }

  it 'falls back to the default locale instead of raising on a malicious locale param' do
    expect do
      get '/sitemap.xml.gz', params: { locale: sqli_probe }
    end.not_to raise_error

    # No sitemap is attached in this test DB, so :not_found is the correct response —
    # the regression this guards against is an unhandled 500 (I18n::InvalidLocale), not
    # the routine 404.
    expect(response).not_to have_http_status(:server_error)
  end

  it 'does not raise on any locale value not in I18n.available_locales' do
    expect do
      get '/sitemap.xml.gz', params: { locale: 'not-a-real-locale' }
    end.not_to raise_error

    expect(response).not_to have_http_status(:server_error)
  end

  # I18n.locale is reset after each request completes, so it can't be inspected from the
  # test after `get` returns — these exercise the actual before_action logic directly,
  # mirroring the unit-test style already used in application_controller_timezone_spec.rb.
  describe '#set_locale (unit)' do
    let(:controller) { BetterTogether::ApplicationController.new }
    let(:fake_session) { {} }

    before do
      allow(controller).to receive_messages(session: fake_session, helpers: double(current_person: nil))
      allow(controller).to receive(:extract_locale_from_accept_language_header).and_return(nil)
    end

    it 'falls back to the default locale for an invalid params[:locale]' do
      allow(controller).to receive(:params).and_return({ locale: 'not-a-real-locale' })

      controller.send(:set_locale)

      expect(I18n.locale.to_s).to eq(I18n.default_locale.to_s)
    end

    it 'falls back to the default locale for the exact malicious probe string' do
      allow(controller).to receive(:params).and_return({ locale: sqli_probe })

      controller.send(:set_locale)

      expect(I18n.locale.to_s).to eq(I18n.default_locale.to_s)
    end

    it 'honors a valid non-default params[:locale]' do
      valid_locale = (I18n.available_locales.map(&:to_s) - [I18n.default_locale.to_s]).first
      skip 'only one locale configured' unless valid_locale
      allow(controller).to receive(:params).and_return({ locale: valid_locale })

      controller.send(:set_locale)

      expect(I18n.locale.to_s).to eq(valid_locale)
    end

    it 'falls back to the default locale for an invalid tampered session[:locale] when no param is present' do
      fake_session[:locale] = 'not-a-real-locale'
      allow(controller).to receive(:params).and_return({})

      controller.send(:set_locale)

      expect(I18n.locale.to_s).to eq(I18n.default_locale.to_s)
    end
  end
end
