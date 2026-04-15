# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host Dashboard Content', :as_platform_manager do
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
  let(:platform_manager) { BetterTogether::User.find_by!(email: 'manager@example.test') }

  describe 'GET /host/dashboard' do
    it 'renders the host dashboard successfully' do
      get better_together.host_dashboard_path(locale: locale)

      expect(response).to have_http_status(:success)

      # Test that the response contains dashboard-related content
      dashboard_content = response.body.downcase
      expect(
        dashboard_content.include?('dashboard') ||
        dashboard_content.include?('host') ||
        dashboard_content.include?('resource')
      ).to be true
    end

    it 'includes resource cards like Communities, Conversations, People' do
      get better_together.host_dashboard_path(locale: locale)

      expect(response).to have_http_status(:success)

      # Test for some of the key resource cards
      content = response.body.downcase
      expect(
        content.include?('communities') ||
        content.include?('conversations') ||
        content.include?('people')
      ).to be true
    end

    it 'surfaces a membership review queue with direct review links' do
      community = create(:better_together_community, name: 'Reviewable Community')
      create(:better_together_joatu_membership_request, target: community, requestor_name: 'Alex Applicant')

      get better_together.host_dashboard_path(locale: locale)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Membership review queue')
      expect(response.body).to include('Reviewable Community')
      expect(response.body).to include(better_together.community_membership_requests_path(community, locale: locale))
    end

    it 'surfaces a federation review queue when the manager can review platform connections' do
      grant_platform_permission(platform_manager, 'manage_network_connections')
      host_platform = BetterTogether::Platform.find_by!(host: true)
      remote_platform = create(:better_together_platform, name: 'Neighbourhood Commons')
      create(:better_together_platform_connection,
             source_platform: host_platform,
             target_platform: remote_platform,
             status: 'pending',
             updated_at: 4.minutes.ago)

      get better_together.host_dashboard_path(locale: locale)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Federation review queue')
      expect(response.body).to include('Neighbourhood Commons')
      expect(response.body).to include(better_together.platform_connections_path(locale: locale))
      expect(response.body).to include(better_together.platform_connection_path(BetterTogether::PlatformConnection.last, locale: locale))
    end
  end
end
