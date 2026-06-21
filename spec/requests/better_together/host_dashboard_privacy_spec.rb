# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::HostDashboard privacy' do
  # rubocop:disable Metrics/AbcSize
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    membership = host_platform.person_platform_memberships.find_or_initialize_by(member: user.person)
    membership.role ||= create(:better_together_role, :platform_role)
    role = membership.role
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    membership.status = :active
    membership.save!
  end
  # rubocop:enable Metrics/AbcSize

  let(:locale) { I18n.default_locale }
  let(:platform_manager) do
    find_or_create_test_user("host-dashboard-manager-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager)
  end

  before do
    sign_in platform_manager
  end

  it 'does not assign private directory or account cards by default' do
    get better_together.host_dashboard_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(assigns(:show_people_card)).to be(false)
    expect(assigns(:show_user_card)).to be(false)
    expect(assigns(:people)).to be_nil
    expect(assigns(:users)).to be_nil
    expect(assigns(:conversations)).to be_nil
    expect(assigns(:messages)).to be_nil
  end

  it 'keeps people and user directory summaries hidden without explicit permissions' do
    create(:better_together_person, name: 'Hidden Directory Person', privacy: 'public')
    create(:better_together_user, :confirmed)

    get better_together.host_dashboard_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(assigns(:show_people_card)).to be(false)
    expect(assigns(:show_user_card)).to be(false)
    expect(assigns(:person_count)).to be_nil
    expect(assigns(:user_count)).to be_nil
    expect(response.body).not_to include('Hidden Directory Person')
  end

  it 'redirects platform connection review without network review permission' do
    get better_together.host_dashboard_platform_connection_review_path(locale:)

    expect(response).to redirect_to(better_together.home_page_path(locale:))
    expect(flash[:error]).to be_present
  end

  it 'redirects safety review without safety review permission' do
    get better_together.host_dashboard_safety_review_path(locale:)

    expect(response).to redirect_to(better_together.home_page_path(locale:))
    expect(flash[:error]).to be_present
  end
end
