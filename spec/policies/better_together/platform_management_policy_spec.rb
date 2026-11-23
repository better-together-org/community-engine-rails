# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformManagementPolicy do
  let(:operator_platform) { create(:better_together_platform, type: 'BetterTogether::OperatorPlatform') }
  let(:managed_platform) { create(:better_together_platform, type: 'BetterTogether::HostedPlatform') }
  let(:edge) do
    create(:better_together_platform_management, :active, operator_platform:, managed_platform:)
  end

  def steward_of(platform)
    BetterTogether::AccessControlBuilder.seed_data unless HostRoles.find('platform_steward')
    user = create(:better_together_user, :confirmed)
    create(:better_together_person_platform_membership, member: user.person, joinable: platform,
                                                        role: HostRoles.find('platform_steward'), status: 'active')
    user
  end

  describe 'managed platform steward' do
    subject(:policy) { described_class.new(steward_of(managed_platform), edge) }

    it 'can view, accept, narrow, suspend, resume and revoke' do
      expect([policy.show?, policy.accept?, policy.narrow?, policy.suspend?, policy.resume?, policy.revoke?])
        .to all(be(true))
    end

    it 'cannot edit or destroy the record directly' do
      expect([policy.update?, policy.destroy?]).to all(be(false))
    end

    it 'cannot create an edge naming an operator it does not steward' do
      expect(described_class.new(steward_of(managed_platform), build(:better_together_platform_management,
                                                                     operator_platform:, managed_platform:)).create?)
        .to be(false)
    end
  end

  describe 'operator platform steward' do
    let(:user) { steward_of(operator_platform) }

    it 'can view the edge and request a new one, but not accept, suspend or revoke it' do
      policy = described_class.new(user, edge)
      expect(policy.show?).to be(true)
      expect([policy.accept?, policy.suspend?, policy.revoke?]).to all(be(false))
      expect(described_class.new(user, build(:better_together_platform_management, operator_platform:,
                                                                                   managed_platform:)).create?)
        .to be(true)
    end

    it 'cannot create an already active edge' do
      record = build(:better_together_platform_management, :active, operator_platform:, managed_platform:)
      expect(described_class.new(user, record).create?).to be(false)
    end
  end

  describe 'a steward of an unrelated platform' do
    subject(:policy) { described_class.new(steward_of(create(:better_together_platform)), edge) }

    it 'is denied everything on the edge' do
      expect([policy.show?, policy.accept?, policy.suspend?, policy.revoke?, policy.create?]).to all(be(false))
    end
  end

  describe 'a guest' do
    subject(:policy) { described_class.new(nil, edge) }

    it 'is denied' do
      expect([policy.index?, policy.show?, policy.accept?]).to all(be(false))
    end
  end

  describe 'Scope' do
    it 'lists only edges touching platforms the user stewards' do
      other = create(:better_together_platform_management, :active)
      edge
      resolved = described_class::Scope.new(steward_of(managed_platform), BetterTogether::PlatformManagement).resolve
      expect(resolved).to include(edge)
      expect(resolved).not_to include(other)
    end
  end
end
