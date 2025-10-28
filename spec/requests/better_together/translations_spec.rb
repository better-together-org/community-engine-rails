require 'rails_helper'

RSpec.describe 'BetterTogether::Translations', type: :request do
  include RequestSpecHelper

  before do
    configure_host_platform
    login('manager@example.test', 'password12345')
  end

  describe 'GET /translations' do
    context 'with default parameters' do
      it 'renders the translations index successfully' do
        get better_together.translations_path(locale: I18n.default_locale)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Translation Management')
        expect(response.body).to include('Translation Data Types Overview')
      end
    end

    context 'with locale filter' do
      it 'renders with locale filter applied' do
        get better_together.translations_path(locale: I18n.default_locale, locale_filter: 'en')

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Active filters')
      end
    end

    context 'with data type filter' do
      it 'renders with data type filter applied' do
        get better_together.translations_path(locale: I18n.default_locale, data_type_filter: 'string')

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Active filters')
      end
    end

    context 'with both locale and data type filters' do
      it 'renders with both filters applied' do
        get better_together.translations_path(locale: I18n.default_locale, locale_filter: 'en',
                                              data_type_filter: 'string')

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Active filters')
        expect(response.body).to include('Locale')
        expect(response.body).to include('Data Type')
      end
    end
  end

  def configure_host_platform
    host_platform = BetterTogether::Platform.find_by(host: true)
    if host_platform
      host_platform.update!(privacy: 'public')
    else
      FactoryBot.create(:better_together_platform, :host, privacy: 'public')
    end

    wizard = BetterTogether::Wizard.find_or_create_by(identifier: 'host_setup')
    wizard.mark_completed

    platform_manager = BetterTogether::User.find_by(email: 'manager@example.test')

    return if platform_manager

    FactoryBot.create(
      :user, :confirmed, :platform_manager,
      email: 'manager@example.test',
      password: 'password12345'
    )
  end
end
