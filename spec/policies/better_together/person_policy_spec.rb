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
  # community: explicit — the factory's own bare `community` association
  # always builds a fresh (default-private) community per person, which
  # would cap this person's 'public' privacy at the privacy ceiling
  # regardless of the host platform's own privacy (see PrivacyCeilingValidatable).
  let(:public_person) do
    create(:better_together_person, privacy: 'public', community: create(:better_together_community, privacy: 'public'))
  end
  let(:private_person) { create(:better_together_person, privacy: 'private') }

  before do
    # This spec tests person-level privacy independent of platform/community
    # privacy — ensure the default host platform (and its community) are
    # public so a person's own 'public' privacy never exceeds the privacy
    # ceiling (see PrivacyCeilingValidatable) for reasons unrelated to what
    # these examples are actually testing.
    BetterTogether::AccessControlBuilder.seed_data
    host_platform = BetterTogether::Platform.find_by(host: true)
    if host_platform
      host_platform.update!(privacy: 'public') unless host_platform.privacy_public?
      host_platform.community&.update!(privacy: 'public') if host_platform.community && !host_platform.community.privacy_public?
    end

    grant_platform_permission(people_reviewer, 'read_person')
  end

  describe '#create?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager, BetterTogether::Person).create?).to be true
    end

    it 'allows an explicit create_person permission holder' do
      grant_platform_permission(people_reviewer, 'create_person')

      expect(described_class.new(people_reviewer, BetterTogether::Person).create?).to be true
    end

    it 'denies a regular user without the permission' do
      regular_user = create(:better_together_user, :confirmed)

      expect(described_class.new(regular_user, BetterTogether::Person).create?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, BetterTogether::Person).create?).to be false
    end
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

  describe '#manage_merchant_account?' do
    it 'denies an ordinary member managing their own payout onboarding' do
      regular_user = create(:better_together_user, :confirmed)

      expect(described_class.new(regular_user, regular_user.person).manage_merchant_account?).to be false
    end

    it 'allows a person with an explicit manage_platform_settings permission' do
      grant_platform_permission(people_reviewer, 'manage_platform_settings')

      expect(described_class.new(people_reviewer, public_person).manage_merchant_account?).to be true
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, public_person).manage_merchant_account?).to be false
    end
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
