# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether reports flow' do
  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('reports-user@example.test', 'SecureTest123!@#', :user) }
  let(:target_person) { create(:better_together_person, name: 'Target Person') }

  before do
    sign_in user
  end

  it 'renders the new report form' do
    get better_together.new_report_path(locale:, reportable_type: 'BetterTogether::Person', reportable_id: target_person.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Report a safety concern')
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
end
