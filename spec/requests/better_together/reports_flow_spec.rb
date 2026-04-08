# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether reports flow' do
  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('reports-user@example.test', 'SecureTest123!@#', :user) }
  let(:target_person) { create(:better_together_person, name: 'Target Person') }
  let(:target_page) { create(:better_together_page, title: 'Shared Page Evidence') }

  before do
    sign_in user
  end

  it 'renders the new report form' do
    get better_together.new_report_path(locale:, reportable_type: 'BetterTogether::Person', reportable_id: target_person.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Report a safety concern')
  end

  it 'returns not found for an invalid reportable type on the new form' do
    get better_together.new_report_path(locale:, reportable_type: 'Kernel', reportable_id: target_person.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'renders the report form for a page target with contextual record details' do
    get better_together.new_report_path(locale:, reportable_type: 'BetterTogether::Page', reportable_id: target_page.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Shared Page Evidence')
    expect(response.body).to include('Reporting')
  end

  it 'creates a report and redirects to report history' do
    expect do
      post better_together.reports_path(locale:), params: {
        report: {
          reportable_type: 'BetterTogether::Person',
          reportable_id: target_person.id,
          category: 'boundary_violation',
          harm_level: 'medium',
          requested_outcome: 'boundary_support',
          reason: 'Need help setting a boundary',
          private_details: 'Repeated unwanted contact',
          consent_to_contact: '1',
          consent_to_restorative_process: '0',
          retaliation_risk: '1'
        }
      }
    end.to(change(BetterTogether::Report, :count).by(1)
      .and(change(BetterTogether::Safety::Case, :count).by(1)))

    expect(response).to have_http_status(:redirect)
    follow_redirect!
    expect(response.body).to include('Current status')
  end

  it 'returns not found for an invalid reportable type on create' do
    post better_together.reports_path(locale:), params: {
      report: {
        reportable_type: 'Kernel',
        reportable_id: target_person.id,
        category: 'boundary_violation',
        harm_level: 'medium',
        requested_outcome: 'boundary_support',
        reason: 'Need help setting a boundary'
      }
    }

    expect(response).to have_http_status(:not_found)
  end

  it 'allows the reporter to add follow-up evidence from the report page' do
    report = create(:report, reporter: user.person, reportable: target_person)

    expect do
      post better_together.report_followup_path(report, locale:), params: {
        report_followup: {
          body: 'I have screenshots and dates to add to the report.'
        }
      }
    end.to change(BetterTogether::Safety::Note, :count).by(1)

    expect(response).to redirect_to(better_together.report_path(report, locale:))
    follow_redirect!
    expect(response.body).to include('More information or appeal')
    expect(response.body).to include('I have screenshots and dates to add to the report.')
  end
end
