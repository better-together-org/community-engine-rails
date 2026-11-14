# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform theme settings', :as_platform_manager do # rubocop:disable RSpec/DescribeClass
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:platform_path) { better_together.platform_path(locale: I18n.default_locale, id: host_platform.slug) }

  def patch_theme(theme, extra = {})
    patch platform_path, params: { platform: { theme: }.merge(extra) }
  end

  it 'saves valid tokens and renders them before the platform Css block' do # rubocop:disable RSpec/MultipleExpectations
    patch_theme('primary' => '#243542', 'accent' => '#EE722A', 'font' => 'tahoma', 'radius' => 'small')

    expect(response).to have_http_status(:see_other)
    expect(host_platform.reload.theme).to include('primary' => '#243542', 'accent' => '#ee722a', 'font' => 'tahoma')

    get platform_path
    expect(response.body).to include('id="platform-theme-style"', '--bts-primary: #243542;')
  end

  it 'rejects an unsafe colour and keeps the old theme' do # rubocop:disable RSpec/MultipleExpectations
    host_platform.update!(theme: { 'primary' => '#243542' })

    patch_theme('primary' => 'red;}</style><script>')

    expect(response).to have_http_status(:unprocessable_content)
    expect(host_platform.reload.theme).to eq('primary' => '#243542')
  end

  it 'saves an applied built-in theme with its preset id' do
    tokens = BetterTogether::PlatformThemeConfig.flat_theme('dark')

    patch_theme(tokens.merge('preset' => 'dark'))

    expect(host_platform.reload.theme).to include('preset' => 'dark', 'page_bg' => '#15181d', 'font' => 'system')
    expect(host_platform.theme_config.low_contrast_pairs).to be_empty
  end

  it 'rejects an unknown theme id' do
    patch_theme('preset' => 'neon', 'primary' => '#243542')

    expect(response).to have_http_status(:unprocessable_content)
    expect(host_platform.reload.theme).not_to include('preset')
  end

  it 'renders the saved theme page background and body colour on the live site' do
    patch_theme(BetterTogether::PlatformThemeConfig.flat_theme('dark').merge('preset' => 'dark'))
    get platform_path

    expect(response.body).to include('--bts-page-bg: #15181d;', 'background-color: var(--bts-page-bg)')
  end

  it 'clears tokens when the fields are emptied' do
    host_platform.update!(theme: { 'primary' => '#243542' })

    patch_theme('primary' => '', 'font' => '')

    expect(host_platform.reload.theme).to eq({})
  end

  it 'sets the site logo on the platform community' do
    png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
    file = Rack::Test::UploadedFile.new(StringIO.new(png), 'image/png', original_filename: 'logo.png')

    patch_theme({}, logo: file)

    expect(host_platform.reload.community.logo).to be_attached
  end

  describe 'light and dark mode' do
    let(:light) { { 'primary' => '#1d4e89', 'page_bg' => '#ffffff', 'body_text' => '#212529', 'link' => '#0b5394' } }

    it 'saves the mode settings and custom dark tokens and renders dark properties under data-bs-theme' do # rubocop:disable RSpec/MultipleExpectations
      patch_theme(light.merge('dark_mode' => 'enabled', 'default_mode' => 'dark', 'dark_source' => 'custom', 'dark_page_bg' => '#101010'))

      expect(host_platform.reload.theme).to include('default_mode' => 'dark', 'dark_source' => 'custom', 'dark_page_bg' => '#101010')
      get platform_path
      expect(response.body).to include('[data-bs-theme="dark"]', '--bts-page-bg: #101010;')
    end

    it 'rejects an unknown mode value' do
      patch_theme(light.merge('default_mode' => 'sepia'))

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'renders the toggle, the head script and the platform default when enabled' do # rubocop:disable RSpec/MultipleExpectations
      host_platform.update!(theme: light.merge('default_mode' => 'dark'))
      get platform_path
      doc = Nokogiri::HTML(response.body)

      expect(doc.at_css('html')['data-bs-theme']).to eq('dark')
      expect(doc.at_css('html')['data-bts-color-mode']).to eq('dark')
      expect(doc.at_css('#color-mode-toggle [role=group][aria-label]')).to be_present
      expect(doc.css('#color-mode-toggle button').map { |b| b['data-mode'] }).to eq(%w[auto light dark])
      expect(doc.css('head script[nonce]').map(&:text).join).to include('prefers-color-scheme')
    end

    it 'leaves auto to the head script and honours a saved cookie' do # rubocop:disable RSpec/MultipleExpectations
      get platform_path
      expect(Nokogiri::HTML(response.body).at_css('html')['data-bs-theme']).to be_nil

      cookies['bts_color_mode'] = 'light'
      get platform_path
      expect(Nokogiri::HTML(response.body).at_css('html')['data-bs-theme']).to eq('light')
    end

    it 'ignores an invalid cookie value' do
      cookies['bts_color_mode'] = 'javascript:alert(1)'
      get platform_path

      expect(Nokogiri::HTML(response.body).at_css('html')['data-bts-color-mode']).to eq('auto')
    end

    it 'hides the toggle and the dark properties and sets no theme when disabled' do # rubocop:disable RSpec/MultipleExpectations
      host_platform.update!(theme: light.merge('dark_mode' => 'disabled'))
      cookies['bts_color_mode'] = 'dark'
      get platform_path
      doc = Nokogiri::HTML(response.body)

      expect(doc.at_css('#color-mode-toggle')).to be_nil
      expect(doc.at_css('html')['data-bs-theme']).to be_nil
      expect(doc.at_css('meta[name=color-scheme]')['content']).to eq('light')
      expect(response.body).not_to include('[data-bs-theme="dark"] {')
    end

    it 'returns derived dark tokens for the settings preview' do # rubocop:disable RSpec/MultipleExpectations
      get better_together.theme_dark_platform_path(locale: I18n.default_locale, id: host_platform.slug),
          params: { theme: { link: '#0b5394', page_bg: '#ffffff' } }, as: :json
      body = response.parsed_body

      expect(response).to have_http_status(:ok)
      expect(body['tokens']).to include('link', 'page_bg')
      expect(body['low_contrast']).to eq([])
    end

    it 'shows the optional dark logo as a second image next to the light logo' do # rubocop:disable RSpec/MultipleExpectations
      png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
      upload = ->(name) { Rack::Test::UploadedFile.new(StringIO.new(png), 'image/png', original_filename: name) }
      patch_theme({}, logo: upload.call('logo.png'), dark_logo: upload.call('dark.png'))
      get platform_path
      doc = Nokogiri::HTML(response.body)

      expect(host_platform.reload.dark_logo).to be_attached
      expect(doc.css('img.bts-logo-dark').size).to eq(1)
      expect(doc.css('img.bts-logo-light').size).to eq(1)
    end
  end
end
