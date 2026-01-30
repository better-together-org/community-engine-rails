# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::User do
  describe 'platform manager factory' do
    subject(:user) { create(:better_together_user, :confirmed, :platform_manager) }

    let(:person) { user.person }
    let(:platform_manager_role) { BetterTogether::Role.find_by(identifier: 'platform_manager') }

    it 'assigns the platform_manager role membership' do
      expect(platform_manager_role).to be_present

      membership = BetterTogether::PersonPlatformMembership.find_by(
        member: person,
        role: platform_manager_role
      )

      expect(membership).to be_present
    end

    it 'grants platform and community permissions' do
      expect(user.permitted_to?('manage_platform')).to be(true)
      expect(user.permitted_to?('create_community')).to be(true)
    end
  end

  describe 'membership cache invalidation' do
    it 'touches the member when a membership is created' do
      BetterTogether::AccessControlBuilder.seed_data

      person = create(:better_together_person)
      platform = BetterTogether::Platform.find_by(host: true) ||
                 create(:better_together_platform, :host, community: person.community)
      role = BetterTogether::Role.find_by(identifier: 'platform_manager')

      expect(role).to be_present

      previous_updated_at = person.updated_at

      create(
        :better_together_person_platform_membership,
        member: person,
        joinable: platform,
        role: role
      )

      expect(person.reload.updated_at).to be > previous_updated_at
    end
  end
end
