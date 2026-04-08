# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Safety::CasePolicy do
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
  let(:safety_reviewer) { create(:better_together_user, :confirmed) }
  let(:reporter_user) { create(:better_together_user, :confirmed) }
  let(:other_user) { create(:better_together_user, :confirmed) }
  let(:safety_case) { create(:report, reporter: reporter_user.person).safety_case }

  before do
    grant_platform_permission(safety_reviewer, 'manage_platform_safety')
  end

  it 'permits explicit safety reviewers to view and update cases' do
    policy = described_class.new(safety_reviewer, safety_case)
    expect(policy.show?).to be true
    expect(policy.update?).to be true
  end

  it 'denies default platform managers without explicit safety authority' do
    policy = described_class.new(platform_manager, safety_case)
    expect(policy.show?).to be false
    expect(policy.update?).to be false
  end

  it 'denies reporters from viewing their own case' do
    policy = described_class.new(reporter_user, safety_case)
    expect(policy.show?).to be false
    expect(policy.update?).to be false
  end

  it 'denies unrelated users' do
    policy = described_class.new(other_user, safety_case)
    expect(policy.show?).to be false
  end
end
