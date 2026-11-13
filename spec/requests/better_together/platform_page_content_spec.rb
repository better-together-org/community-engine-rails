# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform header, footer and 404 content', :as_platform_manager do # rubocop:disable RSpec/DescribeClass
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:platform_path) { better_together.platform_path(locale: I18n.default_locale, id: host_platform.slug) }

  def patch_content(content)
    patch platform_path, params: { platform: { page_content: content } }
  end

  it 'saves content per locale and renders sanitized header and footer around the page' do # rubocop:disable RSpec/MultipleExpectations
    patch_content('header_html' => { 'en' => '<p>Next foray soon</p><script>alert(1)</script>' },
                  'footer_html' => { 'en' => '<p>Footer line</p>' })

    expect(response).to have_http_status(:see_other)
    get platform_path
    doc = parsed_response
    expect(doc.at_css('#platform-header-content').text).to include('Next foray soon')
    expect(doc.at_css('#platform-footer-content').text).to include('Footer line')
    expect(doc.at_css('#platform-header-content script')).to be_nil
  end

  it 'renders one of the configured headlines on the 404 page' do
    patch_content('not_found_headlines' => { 'en' => "Lost in the woods\nNothing here but mushrooms" })

    get better_together.platform_path(locale: I18n.default_locale, id: 'no-such-platform-xyz')

    expect(parsed_response.at_css('#not-found-headline').text).to match(/Lost in the woods|Nothing here but mushrooms/)
  end

  it 'keeps the standard 404 title when no headlines are set' do
    get better_together.platform_path(locale: I18n.default_locale, id: 'no-such-platform-xyz')

    expect(parsed_response.at_css('#not-found-headline').text).to eq(I18n.t('errors.not_found.title'))
  end

  it 'rejects too many headline characters and keeps the old content' do
    host_platform.update!(page_content: { 'header_html' => { 'en' => '<p>Old</p>' } })

    patch_content('not_found_headlines' => { 'en' => 'a' * 200 })

    expect(response).to have_http_status(:unprocessable_content)
    expect(host_platform.reload.page_content).to eq('header_html' => { 'en' => '<p>Old</p>' })
  end
end
