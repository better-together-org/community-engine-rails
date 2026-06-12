# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonPolicy do
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
    user.person.touch
  end
  # rubocop:enable Metrics/AbcSize

  let(:platform_manager) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:people_reviewer) { create(:better_together_user, :confirmed) }
  let(:public_person) { create(:better_together_person, privacy: 'public') }
  let(:private_person) { create(:better_together_person, privacy: 'private') }

  before do
    grant_platform_permission(people_reviewer, 'read_person')
  end

  it 'allows guests to view public profiles' do
    expect(described_class.new(nil, public_person).show?).to be true
  end

  it 'denies default platform managers from viewing unrelated private profiles' do
    expect(described_class.new(platform_manager, private_person).show?).to be false
  end

  it 'permits explicit people reviewers to view private profiles' do
    expect(described_class.new(people_reviewer, private_person).show?).to be true
  end

  describe 'Scope' do
    let(:scope) { BetterTogether::Person }

    it 'limits signed-in users without directory permission to themselves and public profiles' do
      resolved = described_class::Scope.new(platform_manager, scope).resolve

      expect(resolved).to include(platform_manager.person, public_person)
      expect(resolved).not_to include(private_person)
    end

    it 'returns all people for explicit directory reviewers' do
      grant_platform_permission(people_reviewer, 'list_person')

      resolved = described_class::Scope.new(people_reviewer, scope).resolve

      expect(resolved).to include(people_reviewer.person, public_person, private_person)
    end
  end
end
