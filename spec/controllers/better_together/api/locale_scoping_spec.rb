# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Api::LocaleScoping do
  controller(ActionController::Base) do
    include BetterTogether::Api::LocaleScoping # rubocop:disable RSpec/DescribedClass

    def index
      render json: { locale: I18n.locale, mobility: Mobility.locale }
    end
  end

  around do |example|
    original = I18n.locale
    example.run
  ensure
    I18n.locale = original
  end

  it 'is part of the API base controller' do
    expect(BetterTogether::Api::ApplicationController.included_modules).to include(described_class)
  end

  it 'ignores a locale leaked onto the thread by an earlier web request', :aggregate_failures do
    I18n.locale = :es
    get :index

    expect(response.parsed_body['locale']).to eq(I18n.default_locale.to_s)
    expect(response.parsed_body['mobility']).to eq(I18n.default_locale.to_s)
  end

  it 'honours an explicit X-Api-Locale header' do
    request.headers['X-Api-Locale'] = 'fr'
    get :index

    expect(response.parsed_body['locale']).to eq('fr')
  end

  it 'falls back to the default for an unknown locale' do
    request.headers['X-Api-Locale'] = 'xx'
    get :index

    expect(response.parsed_body['locale']).to eq(I18n.default_locale.to_s)
  end

  it 'restores the thread locale afterwards' do
    I18n.locale = :es
    get :index

    expect(I18n.locale).to eq(:es)
  end
end
