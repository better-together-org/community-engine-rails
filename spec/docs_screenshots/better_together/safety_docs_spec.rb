# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for safety flows', :as_user, :docs_screenshot, :js, retry: 0, type: :feature do
  let!(:report_target) { create(:better_together_person, name: 'Safety Docs Target') }
  let!(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let!(:report_record) do
    create(
      :report,
      reporter: user.person,
      reportable: report_target,
      category: 'boundary_violation',
      harm_level: 'medium',
      requested_outcome: 'boundary_support',
      reason: 'Repeated unwanted contact in messages',
      private_details: 'The contact continued after I asked for space.'
    )
  end
  let!(:person_block) { create(:person_block, blocker: user.person, blocked: report_target) }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures safety report form screenshots' do
    capture_docs_screenshot('report_form') do
      visit_report_form
      expect(page).to have_text('Report a safety concern')
    end
  end

  it 'captures report history screenshots' do
    capture_docs_screenshot('report_history') do
      visit_with_login better_together.reports_path(locale: I18n.default_locale)
      expect(page).to have_text('My safety reports')
      expect(page).to have_text('Boundary violation')
    end
  end

  it 'captures report detail screenshots' do
    capture_docs_screenshot('report_detail') do
      visit_with_login better_together.report_path(report_record, locale: I18n.default_locale)
      expect(page).to have_text('Safety report')
      expect(page).to have_text('Repeated unwanted contact in messages')
    end
  end

  it 'captures blocked people list screenshots' do
    capture_docs_screenshot('blocked_people_list') do
      visit_with_login better_together.person_blocks_path(locale: I18n.default_locale)
      expect(page).to have_text('Blocked People')
      expect(page).to have_text(report_target.name)
    end
  end

  it 'captures block person form screenshots' do
    capture_docs_screenshot('block_person_form') do
      visit_with_login better_together.new_person_block_path(locale: I18n.default_locale)
      expect(page).to have_text('Block')
      expect(page).to have_button('Block')
    end
  end

  private

  def capture_docs_screenshot(name, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'user',
        feature_set: 'safety',
        source_spec: self.class.metadata[:file_path]
      },
      &
    )
  end

  def visit_report_form
    sign_in_for_docs_capture
    visit better_together.new_report_path(
      locale: I18n.default_locale,
      reportable_type: 'BetterTogether::Person',
      reportable_id: report_target.id
    )
  end

  def visit_with_login(path)
    sign_in_for_docs_capture
    visit path
  end

  def sign_in_for_docs_capture
    capybara_login_as_user
  end
end
