# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Fleet::NodePolicy, type: :policy do
  subject(:policy) { described_class.new(user, node) }

  let(:node) { create(:better_together_fleet_node) }

  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    membership = host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
    membership.update!(status: 'active') unless membership.active?
  end

  context 'as a guest (nil user)' do
    let(:user) { nil }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_show }
    it { is_expected.not_to be_create }
    it { is_expected.not_to be_update }
  end

  context 'as an authenticated user without manage_platform (fleet service agent)' do
    let(:user) { create(:better_together_user) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_update }
  end

  context 'as a platform manager' do
    let(:user) { create(:better_together_user, :platform_manager) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_update }
  end

  context 'destroy?' do
    let(:user) { create(:better_together_user, :platform_manager) }

    it 'is not permitted even for platform managers' do
      expect(policy).not_to be_destroy
    end
  end

  describe described_class::Scope do
    subject(:resolved) { described_class.new(user, BetterTogether::Fleet::Node.all).resolve }

    let!(:node_a) { create(:better_together_fleet_node) }
    let!(:node_b) { create(:better_together_fleet_node) }

    context 'as a platform manager' do
      let(:user) { create(:better_together_user, :platform_manager) }

      it 'returns all nodes' do
        expect(resolved).to include(node_a, node_b)
      end
    end

    context 'as an authenticated user whose person owns node_a' do
      let(:user) { create(:better_together_user) }

      before do
        BetterTogether::Fleet::NodeOwnership.create!(node: node_a, owner: user.person)
      end

      it 'returns only the nodes the person owns' do
        expect(resolved).to include(node_a)
        expect(resolved).not_to include(node_b)
      end
    end

    context 'as an authenticated user with no owned nodes' do
      let(:user) { create(:better_together_user) }

      it 'returns no nodes (inner join finds no ownership)' do
        expect(resolved).to be_empty
      end
    end

    context 'as a guest' do
      let(:user) { nil }

      it 'returns none' do
        expect(resolved).to be_empty
      end
    end
  end
end
