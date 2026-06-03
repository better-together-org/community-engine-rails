# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonPolicy do
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
  end

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
end
