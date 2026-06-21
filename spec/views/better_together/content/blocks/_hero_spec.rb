# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/_hero.html.erb' do
  before do
    configure_host_platform
  end

  it 'renders custom heading and paragraph colors when configured' do
    hero = create(
      :content_hero,
      heading: 'Colorful Heading',
      subtitle: 'Colorful paragraph',
      heading_color: '#ff6600',
      paragraph_color: '#336699'
    )

    render partial: 'better_together/content/blocks/hero', locals: { hero: }

    page = Capybara.string(rendered)

    expect(page).to have_css('.hero-heading[style*="color: #ff6600"]', text: 'Colorful Heading')
    expect(page).to have_css('.hero-paragraph[style*="color: #336699"]')
    expect(page).to have_text('Colorful paragraph')
  end

  it 'omits inline text color styles when no custom colors are configured' do
    hero = create(
      :content_hero,
      heading: 'Default Heading',
      subtitle: 'Default paragraph',
      heading_color: '',
      paragraph_color: ''
    )

    render partial: 'better_together/content/blocks/hero', locals: { hero: }

    page = Capybara.string(rendered)

    expect(page).to have_css('.hero-heading', text: 'Default Heading')
    expect(page).to have_css('.hero-paragraph')
    expect(page).to have_no_css('.hero-heading[style]')
    expect(page).to have_no_css('.hero-paragraph[style]')
  end
end
