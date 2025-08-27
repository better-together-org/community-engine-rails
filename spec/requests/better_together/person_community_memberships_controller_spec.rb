# frozen_string_literal: true

require 'rails_helper'

# rubocop:todo Metrics/BlockLength
RSpec.describe 'BetterTogether::PersonCommunityMembershipsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  describe 'POST /:locale/.../host/communities/:community_id/person_community_memberships' do
    # rubocop:todo RSpec/ExampleLength
    # rubocop:todo RSpec/MultipleExpectations
    it 'creates a membership and redirects when actor has update_community permission' do
      # rubocop:enable RSpec/MultipleExpectations
      community = create(:better_together_community)

      # Ensure current user has the required permission on this community
      coordinator_role = BetterTogether::Role.find_by(identifier: 'community_coordinator')
      BetterTogether::PersonCommunityMembership.create!(
        joinable: community,
        member: BetterTogether::User.find_by(email: 'manager@example.test').person,
        role: coordinator_role
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
        role: coordinator_role
      )

      member = create(:better_together_person)
      target_role = BetterTogether::Role.find_by(identifier: 'community_member')
      membership = BetterTogether::PersonCommunityMembership.create!(
        joinable: community,
        member: member,
        role: target_role
      )

      delete better_together.community_person_community_membership_path(locale:, community_id: community.id,
                                                                        id: membership.id)
      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end
end
# rubocop:enable Metrics/BlockLength
