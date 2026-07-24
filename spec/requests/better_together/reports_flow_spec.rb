# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether reports flow' do
  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('reports-user@example.test', 'SecureTest123!@#', :user) }
  let(:other_user) { find_or_create_test_user('reports-other-user@example.test', 'SecureTest123!@#', :user) }
  let(:target_person) { create(:better_together_person, name: 'Target Person') }
  let(:target_page) { create(:better_together_page, title: 'Shared Page Evidence') }
  let(:target_block) { create(:better_together_content_rich_text, content_html: '<p>Block evidence</p>') }

  def bot_defense_payload(form_id)
    challenge = travel_to(3.seconds.ago) do
      BetterTogether::BotDefense::Challenge.issue(form_id:)
    end

    {
      bot_defense: {
        token: challenge.token,
        trap_values: { challenge.trap_field => '' }
      }
    }
  end

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
    expect(response.body).to include('Who can see and act on this report')
    expect(response.body).to include('Sent privately to the platform safety team')
    expect(response.body).to include('Visible after submission only to you and platform safety reviewers.')
  end

  it 'renders the report form for a content block target' do
    get better_together.new_report_path(locale:, reportable_type: 'BetterTogether::Content::Block', reportable_id: target_block.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Report a safety concern')
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
      }.merge(bot_defense_payload(:safety_report))
    end.to(change(BetterTogether::Report, :count).by(1)
      .and(change(BetterTogether::Safety::Case, :count).by(1)))

    expect(response).to have_http_status(:redirect)
    follow_redirect!
    expect(response.body).to include('Current status')
  end

  it 'shows only the signed-in reporter reports in history' do
    own_report = create(:report,
                        reporter: user.person,
                        reportable: target_person,
                        reason: 'My own report history entry')
    create(:report,
           reporter: other_user.person,
           reportable: target_person,
           reason: 'Someone else history entry')

    get better_together.reports_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(own_report.reason)
    expect(response.body).not_to include('Someone else history entry')
  end

  it 'allows the reporter to view their own report' do
    report = create(:report, reporter: user.person, reportable: target_person)

    get better_together.report_path(report, locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Current status')
    expect(response.body).to include('More information or appeal')
  end

  it 'returns not found when another signed-in user tries to view the report' do
    report = create(:report, reporter: user.person, reportable: target_person)
    sign_in other_user

    get better_together.report_path(report, locale:)

    expect(response).to have_http_status(:not_found)
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
    }.merge(bot_defense_payload(:safety_report))

    expect(response).to have_http_status(:not_found)
  end

  it 'rejects report creation without bot defense proof' do
    expect do
      post better_together.reports_path(locale:), params: {
        report: {
          reportable_type: 'BetterTogether::Person',
          reportable_id: target_person.id,
          category: 'boundary_violation',
          harm_level: 'medium',
          requested_outcome: 'boundary_support',
          reason: 'Need help setting a boundary'
        }
      }
    end.not_to change(BetterTogether::Report, :count)

    expect(response).to have_http_status(:unprocessable_content)
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

  it 'returns not found when another signed-in user tries to add follow-up evidence' do
    report = create(:report, reporter: user.person, reportable: target_person)
    sign_in other_user

    expect do
      post better_together.report_followup_path(report, locale:), params: {
        report_followup: {
          body: 'I should not be able to append evidence here.'
        }
      }
    end.not_to change(BetterTogether::Safety::Note, :count)

    expect(response).to have_http_status(:not_found)
  end
end
