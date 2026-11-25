# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Membership lifecycle actions' do # rubocop:disable RSpec/DescribeClass
  let!(:platform) { BetterTogether::Platform.find_by(host: true) || configure_host_platform }
  let(:member_role) { BetterTogether::Role.find_by!(identifier: 'platform_analytics_viewer') }
  let(:person) { create(:better_together_person, platform_id: platform.id) }
  let(:membership) do
    BetterTogether::PersonPlatformMembership.create!(member: person, joinable: platform, role: member_role,
                                                     status: 'active')
  end
  let(:locale) { I18n.default_locale }

  context 'as a platform manager', :as_platform_manager do
    it 'ends a membership and keeps the row as history' do
      patch end_membership_platform_person_platform_membership_path(platform, membership, locale:),
            params: { reason: 'Moved away' }

      expect(response).to redirect_to(platform_path(platform, locale:))
      expect(membership.reload).to have_attributes(status: 'ended', ended_reason: 'Moved away')
    end

    it 'suspends then reinstates a membership' do
      patch suspend_platform_person_platform_membership_path(platform, membership, locale:)
      expect(membership.reload.status).to eq('suspended')

      patch reinstate_platform_person_platform_membership_path(platform, membership, locale:)
      expect(membership.reload).to have_attributes(status: 'active', ends_at: nil)
    end

    it 'records who acted in the event trail' do
      patch suspend_platform_person_platform_membership_path(platform, membership, locale:)

      event = membership.membership_events.find_by!(event_type: 'suspended')
      expect(event.actor).to eq(BetterTogether::User.find_by(email: 'manager@example.test')&.person || event.actor)
    end

    it 'lets a steward end another steward while one remains' do
      other = create(:better_together_person, platform_id: platform.id)
      steward_role = BetterTogether::Role.find_by!(identifier: 'platform_steward')
      other_membership = BetterTogether::PersonPlatformMembership.create!(member: other, joinable: platform,
                                                                          role: steward_role, status: 'active')

      patch end_membership_platform_person_platform_membership_path(platform, other_membership, locale:)

      expect(other_membership.reload.status).to eq('ended')
    end
  end

  context 'as a community member', :as_user do
    let(:community) { create(:better_together_community) }
    let(:role) { BetterTogether::Role.find_by!(identifier: 'community_member') }

    it 'lets a member leave but not end someone else', :aggregate_failures do
      leaver = BetterTogether::User.find_by!(email: 'user@example.test').person
      own = BetterTogether::PersonCommunityMembership.create!(member: leaver, joinable: community, role:,
                                                              status: 'active')
      other = BetterTogether::PersonCommunityMembership.create!(member: person, joinable: community, role:,
                                                                status: 'active')

      patch end_membership_community_person_community_membership_path(community.id, other, locale:)
      expect(other.reload.status).to eq('active')

      delete leave_community_person_community_membership_path(community.id, own, locale:)
      expect(own.reload).to have_attributes(status: 'ended', ended_reason: 'left')
    end
  end
end
