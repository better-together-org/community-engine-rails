# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Report form accessibility', :accessibility, :as_user, :js, retry: 0 do
  let!(:target_person) { create(:better_together_person, name: 'Accessibility Target') }
  let(:supported_locales) { I18n.available_locales }

  before do
    capybara_login_as_user
  end

  it 'passes WCAG 2.1 AA accessibility checks for the report intake form in each supported locale',
     :aggregate_failures do
    supported_locales.each do |locale|
      visit_report_form(locale)

      expect(page).to be_axe_clean
        .within('main')
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
    end
  end

  it 'connects field help text and consent guidance to the form controls in each supported locale',
     :aggregate_failures do
    supported_locales.each do |locale|
      visit_report_form(locale)

      category_field = find('#report_category', visible: :all)
      harm_level_field = find('#report_harm_level', visible: :all)
      requested_outcome_field = find('#report_requested_outcome', visible: :all)
      summary_field = find('#report_reason', visible: :all)
      details_field = find('#report_private_details', visible: :all)

      expect(category_field['aria-describedby']).to include('report_category_help')
      expect(harm_level_field['aria-describedby']).to include('report_harm_level_help')
      expect(requested_outcome_field['aria-describedby']).to include('report_requested_outcome_help')
      expect(summary_field['aria-describedby']).to include('report_reason_help')
      expect(details_field['aria-describedby']).to include('report_private_details_help')

      expect(page).to have_css('#report_safety_preferences_help')
      expect(page).to have_text(I18n.t('better_together.reports.new.preferences_help', locale:))
    end
  end

  def visit_report_form(locale)
    visit better_together.new_report_path(
      locale:,
      reportable_type: 'BetterTogether::Person',
      reportable_id: target_person.id
    )

    expect(page).to have_css('form', wait: 10, visible: :all) # rubocop:disable RSpec/ExpectInHook
  end
end
