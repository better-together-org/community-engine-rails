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
