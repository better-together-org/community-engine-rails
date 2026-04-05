# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Safety::Cases' do
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
  end

  let(:locale) { I18n.default_locale }
  let(:platform_manager) { find_or_create_test_user('safety-manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let!(:safety_case) { create(:report, category: 'harassment', harm_level: 'high', requested_outcome: 'temporary_protection').safety_case }

  before do
    grant_platform_permission(platform_manager, 'manage_platform_safety')
    sign_in platform_manager
  end

  it 'renders the host safety queue' do
    get better_together.safety_cases_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Safety cases')
    expect(response.body).to include('Local review snapshot')
    expect(response.body).to include('harassment'.humanize)
    expect(assigns(:local_review_snapshot)[:open_cases_count]).to eq(1)
  end

  it 'allows a platform manager to update the case status' do
    patch better_together.safety_case_path(locale:, id: safety_case.id), params: {
      safety_case: {
        status: 'triaged',
        lane: safety_case.lane,
        closure_summary: 'Initial triage complete'
      }
    }

    expect(response).to have_http_status(:redirect)
    expect(safety_case.reload.status).to eq('triaged')
  end
end
