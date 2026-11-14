# frozen_string_literal: true

require 'rails_helper'

# A signed-in person chooses a theme and a colour mode in their settings.
RSpec.describe 'User theme preferences' do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:cfg) { BetterTogether::PlatformThemeConfig }
  let(:acme_tokens) { cfg.builtin_themes['neutral'].except('dark').merge('primary' => '#0b3d2e', 'page_bg' => '#fffdf8') }

  after { cfg.reset_registered_themes! }

  def save_pref(person, params, via: :settings)
    if via == :settings
      patch update_settings_preferences_path(locale:), params: { person: params }
    else
      patch better_together.person_path(person, locale:), params: { person: params }, as: :json
    end
  end

  # The spec login keeps its own user object in memory, so sign in again to load the stored preferences.
  def store_prefs(person, attrs)
    person.update!(attrs)
    login('user@example.test', 'SecureTest123!@#')
  end

  describe 'signed in as a regular person', :as_user do
    let!(:user) { BetterTogether::User.find_by(email: 'user@example.test') }
    let(:person) { user.person }

    it 'stores a built-in theme and a colour mode in the person preferences' do # rubocop:disable RSpec/MultipleExpectations
      save_pref(person, { theme: 'warm', color_mode: 'dark' })

      expect(response).to have_http_status(:redirect)
      expect(person.reload.preferences).to include('theme' => 'warm', 'color_mode' => 'dark')
    end

    it 'accepts a host-registered theme' do
      cfg.register_theme('acme_forest', acme_tokens, name: 'Acme forest')

      save_pref(person, { theme: 'acme_forest' })

      expect(person.reload.theme).to eq('acme_forest')
    end

    it 'rejects an unknown theme id and an unknown colour mode' do # rubocop:disable RSpec/MultipleExpectations
      save_pref(person, { theme: 'neon' })
      expect(response).to have_http_status(:unprocessable_content)
      expect(person.reload.theme).to be_nil

      save_pref(person, { color_mode: 'sepia' })
      expect(response).to have_http_status(:unprocessable_content)
      expect(person.reload.color_mode).to be_nil
    end

    it 'clears the theme when the platform theme option (blank) is chosen' do
      store_prefs(person, theme: 'warm')

      save_pref(person, { theme: '' })

      expect(person.reload.theme).to be_nil
    end

    it 'saves through the per-field JSON endpoint of the settings form' do # rubocop:disable RSpec/MultipleExpectations
      save_pref(person, { theme: 'cool' }, via: :people)
      expect(response).to have_http_status(:ok)
      expect(person.reload.theme).to eq('cool')

      save_pref(person, { color_mode: 'light' }, via: :people)
      expect(person.reload.color_mode).to eq('light')
    end

    it 'does not let a person write other preference or attribute names through these params' do
      save_pref(person, { theme: 'warm', preferences: { 'x' => 'y' }, css: 'body{display:none}' })

      expect(person.reload.preferences.keys).not_to include('x', 'css')
    end

    it 'does not change another person' do
      other = create(:better_together_person)

      save_pref(other, { theme: 'warm', color_mode: 'dark' }, via: :people)

      expect(other.reload.theme).to be_nil
      expect(other.color_mode).to be_nil
    end

    context 'when the platform turns personal themes off' do
      before { host_platform.update!(allow_user_themes: false) }

      it 'ignores the theme server side but still saves the colour mode' do # rubocop:disable RSpec/MultipleExpectations
        save_pref(person, { theme: 'warm', color_mode: 'dark' })

        expect(person.reload.theme).to be_nil
        expect(person.color_mode).to eq('dark')
      end

      it 'does not render a stored theme' do
        store_prefs(person, theme: 'warm')

        get better_together.platform_path(host_platform, locale:)

        expect(response.body).not_to include('id="user-theme-style"')
      end

      it 'hides the theme control but keeps the colour mode control' do # rubocop:disable RSpec/MultipleExpectations
        get settings_path(locale:)
        doc = Nokogiri::HTML(response.body)

        expect(doc.at_css('#person_theme')).to be_nil
        expect(doc.at_css('#person-theme-disabled-note')).to be_present
        expect(doc.at_css('#person_color_mode')).to be_present
      end
    end

    describe 'rendering' do
      it 'renders the chosen theme after the platform theme and before the platform Css block' do # rubocop:disable RSpec/MultipleExpectations
        host_platform.update!(theme: { 'primary' => '#243542' })
        store_prefs(person, theme: 'warm')

        get better_together.platform_path(host_platform, locale:)
        body = response.body

        expect(body).to include('id="user-theme-style"', "--bts-primary: #{cfg.themes['warm']['primary']};")
        expect(body.index('id="platform-theme-style"')).to be < body.index('id="user-theme-style"')
        expect(body).to include('data-bts-user-theme="warm"')
      end

      it 'renders a registered theme with derived dark tokens' do # rubocop:disable RSpec/MultipleExpectations
        cfg.register_theme('acme_forest', acme_tokens)
        store_prefs(person, theme: 'acme_forest')

        get better_together.platform_path(host_platform, locale:)

        expect(response.body).to include('id="user-theme-style"', '--bts-primary: #0b3d2e;', '[data-bs-theme="dark"]')
      end

      it 'renders the stored colour mode server side with no flash and mirrors it for the head script' do # rubocop:disable RSpec/MultipleExpectations
        store_prefs(person, color_mode: 'dark')

        get better_together.platform_path(host_platform, locale:)

        expect(response.body).to include('data-bts-color-mode="dark"', 'data-bs-theme="dark"', 'data-bts-user-mode="dark"')
      end

      it 'prefers the stored colour mode over a stale cookie' do
        store_prefs(person, color_mode: 'light')
        cookies[BetterTogether::ApplicationHelper::COLOR_MODE_COOKIE] = 'dark'

        get better_together.platform_path(host_platform, locale:)

        expect(response.body).to include('data-bts-color-mode="light"')
      end

      it 'gives a person dark tokens even when the platform turned dark mode off' do # rubocop:disable RSpec/MultipleExpectations
        host_platform.update!(theme: cfg.flat_theme('neutral').merge('dark_mode' => 'disabled'))
        store_prefs(person, color_mode: 'dark')

        get better_together.platform_path(host_platform, locale:)

        expect(response.body).to include('id="color-mode-toggle"', 'id="user-theme-style"', '[data-bs-theme="dark"]')
      end

      it 'renders no per-person style without a theme choice' do
        get better_together.platform_path(host_platform, locale:)

        expect(response.body).not_to include('id="user-theme-style"')
      end
    end

    describe 'settings form' do
      it 'lists the platform option, every built-in theme and every registered theme' do # rubocop:disable RSpec/MultipleExpectations
        cfg.register_theme('acme_forest', acme_tokens, name: 'Acme forest')

        get settings_path(locale:)
        options = Nokogiri::HTML(response.body).css('#person_theme option')

        expect(options.map { |o| o['value'] }).to eq([''] + cfg.themes.keys)
        expect(options.map(&:text)).to include('Acme forest', "Use the platform's theme")
      end

      it 'offers automatic, light and dark and preselects the stored mode' do # rubocop:disable RSpec/MultipleExpectations
        store_prefs(person, color_mode: 'light')

        get settings_path(locale:)
        select = Nokogiri::HTML(response.body).at_css('#person_color_mode')

        expect(select.css('option').map { |o| o['value'] }).to eq(%w[auto light dark])
        expect(select.at_css('option[selected]')['value']).to eq('light')
      end
    end
  end

  describe 'as a platform manager', :as_platform_manager do
    it 'cannot change another person theme or colour mode' do
      other = create(:better_together_person)

      save_pref(other, { theme: 'warm', color_mode: 'dark' }, via: :people)

      expect(other.reload.preferences).not_to include('theme', 'color_mode')
    end
  end

  describe 'anonymous visitors', :no_auth do
    it 'are unaffected: no per-person style and the platform default mode' do # rubocop:disable RSpec/MultipleExpectations
      get better_together.platform_path(host_platform, locale:)

      expect(response.body).not_to include('id="user-theme-style"', 'data-bts-user-mode="')
    end

    it 'still use the cookie for their colour mode' do
      cookies[BetterTogether::ApplicationHelper::COLOR_MODE_COOKIE] = 'dark'

      get better_together.platform_path(host_platform, locale:)

      expect(response.body).to include('data-bts-color-mode="dark"')
    end
  end
end
