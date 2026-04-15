# frozen_string_literal: true

require 'rails_helper'

# rubocop:todo Metrics/BlockLength
# rubocop:todo RSpec/MultipleDescribes
RSpec.describe 'BetterTogether::PersonCommunityMembershipsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'POST /:locale/.../host/communities/:community_id/person_community_memberships' do
    it 'creates a membership and redirects when actor has update_community permission' do
      # rubocop:enable RSpec/MultipleExpectations
      community = create(:better_together_community)

      # Ensure current user has the required permission on this community
      coordinator_role = BetterTogether::Role.find_by(identifier: 'community_coordinator')
      BetterTogether::PersonCommunityMembership.create!(
        joinable: community,
        member: BetterTogether::User.find_by(email: 'manager@example.test').person,
        role: coordinator_role,
        status: 'active'
      )

      member = create(:better_together_person)
      target_role = BetterTogether::Role.find_by(identifier: 'community_member')

      post better_together.community_person_community_memberships_path(locale:, community_id: community.id), params: {
        person_community_membership: {
          member_id: member.id,
          role_id: target_role.id
        }
      }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    # rubocop:enable RSpec/ExampleLength
  end

  describe 'DELETE /:locale/.../host/communities/:community_id/person_community_memberships/:id' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'destroys a membership and redirects' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      community = create(:better_together_community)
      coordinator_role = BetterTogether::Role.find_by(identifier: 'community_coordinator')
      BetterTogether::PersonCommunityMembership.create!(
        joinable: community,
        member: BetterTogether::User.find_by(email: 'manager@example.test').person,
        role: coordinator_role,
        status: 'active'
      )

      member = create(:better_together_person)
      target_role = BetterTogether::Role.find_by(identifier: 'community_member')
      membership = BetterTogether::PersonCommunityMembership.create!(
        joinable: community,
        member: member,
        role: target_role,
        status: 'active'
      )

      delete better_together.community_person_community_membership_path(locale:, community_id: community.id,
                                                                        id: membership.id)
      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end

RSpec.describe 'BetterTogether::PersonCommunityMembershipsController self-service' do
  let(:locale) { I18n.default_locale }
  let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }

  describe 'POST /:locale/.../host/communities/:community_id/person_community_memberships', :as_user do
    # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
    it 'creates an active membership when direct join is allowed' do
      community = create(:better_together_community, :open_access)

      expect do
        post better_together.community_person_community_memberships_path(locale:, community_id: community.id), params: {
          person_community_membership: {
            self_service: '1'
          }
        }
      end.to change(BetterTogether::PersonCommunityMembership, :count).by(1)

      membership = BetterTogether::PersonCommunityMembership.order(:created_at).last
      expect(membership.joinable).to eq(community)
      expect(membership.member).to eq(BetterTogether::User.find_by(email: 'user@example.test').person)
      expect(membership.role).to eq(community_member_role)
      expect(membership.status).to eq('active')
      expect(response).to redirect_to(community)
    end
    # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations

    # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
    it 'creates a pending membership when request mode is enabled' do
      community = create(:better_together_community, :membership_requests_enabled)
      create(:better_together_platform, :membership_requests_enabled, community: community)

      expect do
        post better_together.community_person_community_memberships_path(locale:, community_id: community.id), params: {
          person_community_membership: {
            self_service: '1'
          }
        }
      end.to change(BetterTogether::PersonCommunityMembership, :count).by(1)

      membership = BetterTogether::PersonCommunityMembership.order(:created_at).last
      expect(membership.joinable).to eq(community)
      expect(membership.status).to eq('pending')
      expect(response).to redirect_to(community)
    end
    # rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
  end
end
# rubocop:enable RSpec/MultipleDescribes
# rubocop:enable Metrics/BlockLength
