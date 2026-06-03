# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Safety::NotePolicy do
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
  let(:safety_case) { create(:report).safety_case }
  let(:note_record) { BetterTogether::Safety::Note.new(safety_case:, author: safety_reviewer.person) }

  before do
    grant_platform_permission(safety_reviewer, 'manage_platform_safety')
  end

  it 'permits explicit safety reviewers to create notes' do
    expect(described_class.new(safety_reviewer, note_record).create?).to be true
  end

  it 'denies default platform managers without explicit safety authority' do
    expect(described_class.new(platform_manager, note_record).create?).to be false
  end
end
