# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PersonPlatformMemberships assignment guard', :as_platform_manager do # rubocop:disable RSpec/DescribeClass
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:foreign_person) { create(:better_together_person, platform_id: create(:better_together_platform).id) }
  let(:role) { BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer') }

  it 'rejects a member from another platform' do
    expect do
      post platform_person_platform_memberships_path(platform),
           params: { person_platform_membership: { member_id: foreign_person.id, role_id: role.id },
                     locale: I18n.default_locale }
    end.not_to change(BetterTogether::PersonPlatformMembership, :count)
  end

  it 'rejects a role that is not a platform role' do
    community_role = BetterTogether::Role.find_by(resource_type: 'BetterTogether::Community')
    expect do
      post platform_person_platform_memberships_path(platform),
           params: { person_platform_membership: { member_id: foreign_person.id, role_id: community_role.id },
                     locale: I18n.default_locale }
    end.not_to change(BetterTogether::PersonPlatformMembership, :count)
  end
end
