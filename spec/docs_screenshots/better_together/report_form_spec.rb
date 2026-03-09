# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for report form', :as_user, :docs_screenshot, :js, retry: 0, type: :feature do
  let!(:target_person) { create(:better_together_person, name: 'Documentation Target') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures desktop and mobile screenshots for the report form' do
    path = better_together.new_report_path(
      locale: I18n.default_locale,
      reportable_type: 'BetterTogether::Person',
      reportable_id: target_person.id
    )

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'report_form',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'user',
        flow: 'report_intake',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_user
      visit path

      expect(page).to have_css('form', wait: 10)
      expect(page).to have_text('Report a safety concern')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/report_form.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/report_form.png')
  end
end
