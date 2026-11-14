# frozen_string_literal: true

require 'rails_helper'

# Whole-site axe pass over the default public pages, at desktop and mobile widths.
RSpec.describe 'Site-wide accessibility', :accessibility, :js, :skip_host_setup, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let!(:static_page) do
    create(:better_together_page, slug: 'axe-static', identifier: 'axe-static', title: 'Axe static page',
                                  protected: false, privacy: 'public', published_at: 1.day.ago)
  end
  let(:rules) { %i[wcag2a wcag2aa wcag21a wcag21aa] }

  before do
    static_page.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Section'), position: 0)
  end

  { desktop: [1440, 1000], mobile: [430, 900] }.each do |device, (width, height)|
    context "at #{device} width" do
      before { page.driver.browser.manage.window.resize_to(width, height) }

      it 'has no violations on the static page, including header, nav and footer', :aggregate_failures do
        visit better_together.render_page_path(path: static_page.slug, locale: I18n.default_locale)

        expect(page).to have_css('main#main-content', wait: 10)
        expect(page).to be_axe_clean.according_to(*rules)
      end

      it 'has no violations on the sign-in page' do
        visit new_user_session_path(locale: I18n.default_locale)

        expect(page).to have_css('main#main-content', wait: 10)
        expect(page).to be_axe_clean.according_to(*rules)
      end
    end
  end

  it 'moves focus to the main landmark through the skip link' do
    visit better_together.render_page_path(path: static_page.slug, locale: I18n.default_locale)
    page.send_keys(:tab)

    expect(page).to have_css('#skip-to-content:focus', wait: 5)
    find('#skip-to-content').click
    expect(page).to have_current_path(/#main-content\z/, url: true)
    expect(page).to have_css('main#main-content:focus', wait: 5)
  end
end
