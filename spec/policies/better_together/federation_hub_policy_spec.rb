# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederationHubPolicy, type: :policy do
  subject(:policy) { described_class.new(user, :federation_hub) }

  context 'as a guest (nil user)' do
    let(:user) { nil }

    it { is_expected.not_to be_show }
    it { is_expected.not_to be_activity }
    it { is_expected.not_to be_manage_connections_section }
  end

  context 'as a regular authenticated user' do
    let(:user) { create(:better_together_user) }

    it { is_expected.to be_show }
    it { is_expected.to be_activity }
    it { is_expected.not_to be_manage_connections_section }
  end

  context 'as a network admin' do
    let(:user) { create(:better_together_user, :network_admin) }

    it { is_expected.to be_show }
    it { is_expected.to be_manage_connections_section }
  end

  context 'as an approval-only operator' do
    let(:user) { create(:better_together_user, :confirmed) }

    before do
      permission = BetterTogether::ResourcePermission.find_by(identifier: 'approve_network_connections')
      role = create(:better_together_role, :platform_role)
      BetterTogether::RoleResourcePermission.create!(role:, resource_permission: permission)
      host_platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)
      create(:better_together_person_platform_membership, member: user.person, joinable: host_platform, role:)
    end

    it { is_expected.to be_show }
    it { is_expected.to be_manage_connections_section }
  end
end
