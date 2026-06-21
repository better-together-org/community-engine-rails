# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Page feedback bar accessibility', :accessibility, :as_user, :js, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let!(:host_platform) { configure_host_platform }
  let!(:page_record) do
    create(
      :better_together_page,
      slug: 'page-feedback-bar',
      identifier: 'page-feedback-bar',
      title: 'Accessible feedback page',
      protected: false,
      privacy: 'public',
      published_at: 1.day.ago
    )
  end

  before do
    host_platform
    capybara_login_as_user
  end

  it 'passes WCAG 2.1 AA accessibility checks and keeps the report control described in each locale',
     :aggregate_failures do
    I18n.available_locales.each do |locale|
      visit better_together.render_page_path(page_record.slug, locale:)

      expect(page).to have_css('.bt-page-feedback-bar', wait: 10)
      expect(page).to have_link(I18n.t('better_together.feedback_surface.page_bar.action', locale:))

      report_link = find('.bt-page-feedback-bar__button', visible: :all)
      expect(report_link['aria-describedby']).to be_present
      expect(page).to have_css("##{report_link['aria-describedby']}")

      expect(page).to be_axe_clean
        .within('.bt-page-feedback-bar')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end
end
