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
    tokens = BetterTogether::PlatformThemeConfig.themes['dark']

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
    patch_theme(BetterTogether::PlatformThemeConfig.themes['dark'].merge('preset' => 'dark'))
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
end
