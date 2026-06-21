# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CSP embed accessibility', :accessibility, :js, retry: 0 do
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  before do
    configure_host_platform
  end

  describe 'host platform CSP settings' do
    before do
      capybara_login_as_platform_manager
      visit better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug)

      if page.has_field?('user[email]', disabled: false) # rubocop:disable Style/GuardClause
        capybara_login_as_platform_manager
        visit better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug)
      end
    end

    it 'passes WCAG 2.1 AA accessibility checks' do
      expect(page).to have_css("form[action*='/platforms/']", wait: 10)
      expect(page).to be_axe_clean
        .within('main')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end

  describe 'blocked iframe fallback on rendered pages' do
    let!(:page_record) { create(:better_together_page, :published_public) }
    let!(:iframe_block) { create(:content_iframe_block, title_en: 'Community survey') }

    before do
      host_platform.update!(settings: host_platform.settings.except('csp_frame_src'))
      create(:page_content_block, page: page_record, block: iframe_block)
      visit better_together.render_page_path(page_record.slug, locale: I18n.default_locale)
    end

    it 'passes WCAG 2.1 AA accessibility checks' do
      expect(page).to have_content(I18n.t('better_together.content.blocks.embeds.blocked_title'))
      expect(page).to be_axe_clean
        .within('.iframe-block__notice')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end
end
