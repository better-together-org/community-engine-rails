# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FeatureGate do
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:regular_user) { create(:better_together_user, :confirmed) }

  describe '.enabled?' do
    it 'allows stable features for signed-in users without elevated feature access' do
      expect(described_class.enabled?('developer_settings', actor: regular_user, platform:)).to be(true)
    end

    it 'denies beta features to users without beta access' do
      platform.update!(feature_gate_rollouts: { 'device_permissions' => 'beta' })

      expect(described_class.enabled?('device_permissions', actor: regular_user, platform:)).to be(false)
    end

    it 'allows beta features to platform staff with feature access permissions' do
      platform.update!(feature_gate_rollouts: { 'device_permissions' => 'beta' })

      expect(described_class.enabled?('device_permissions', actor: manager_user, platform:)).to be(true)
    end

    it 'allows explicitly granted access even when the platform rollout is off' do
      platform.update!(feature_gate_rollouts: { 'device_permissions' => 'off' })
      create(:better_together_feature_access_grant,
             platform:,
             person: regular_user.person,
             granted_by_person: manager_user.person,
             feature_key: 'device_permissions',
             access_level: 'beta')

      expect(described_class.enabled?('device_permissions', actor: regular_user, platform:)).to be(true)
    end

    it 'ignores expired explicit grants' do
      platform.update!(feature_gate_rollouts: { 'device_permissions' => 'off' })
      create(:better_together_feature_access_grant,
             platform:,
             person: regular_user.person,
             granted_by_person: manager_user.person,
             feature_key: 'device_permissions',
             access_level: 'beta',
             expires_at: 1.hour.ago)

      expect(described_class.enabled?('device_permissions', actor: regular_user, platform:)).to be(false)
    end

    it 'ignores revoked explicit grants' do
      platform.update!(feature_gate_rollouts: { 'device_permissions' => 'off' })
      grant = create(:better_together_feature_access_grant,
                     platform:,
                     person: regular_user.person,
                     granted_by_person: manager_user.person,
                     feature_key: 'device_permissions',
                     access_level: 'beta')
      grant.revoke!

      expect(described_class.enabled?('device_permissions', actor: regular_user, platform:)).to be(false)
    end

    it 'requires alpha-capable access for alpha rollout' do
      platform.update!(feature_gate_rollouts: { 'device_permissions' => 'alpha' })
      beta_only_user = create(:better_together_user, :confirmed, email: 'beta-only@example.test')
      permission = BetterTogether::ResourcePermission.find_by(identifier: 'access_beta_features')
      role = create(:better_together_role, :platform_role)
      BetterTogether::RoleResourcePermission.create!(role:, resource_permission: permission)
      create(:better_together_person_platform_membership,
             joinable: platform,
             member: beta_only_user.person,
             role:,
             status: 'active')

      expect(described_class.enabled?('device_permissions', actor: beta_only_user, platform:)).to be(false)
    end

    it 'raises for unknown feature keys' do
      expect do
        described_class.enabled?('unknown_feature', actor: regular_user, platform:)
      end.to raise_error(KeyError)
    end
  end

  describe '.actor_level_for' do
    it 'returns the highest available level between role-based and explicit access' do
      platform.update!(feature_gate_rollouts: { 'device_permissions' => 'alpha' })
      create(:better_together_feature_access_grant,
             platform:,
             person: regular_user.person,
             granted_by_person: manager_user.person,
             feature_key: 'device_permissions',
             access_level: 'alpha')

      expect(described_class.actor_level_for('device_permissions', actor: regular_user, platform:)).to eq(:alpha)
    end
  end

  describe '.rollout_for' do
    it 'falls back to the registry default when no explicit platform is given' do
      expect(described_class.rollout_for('developer_settings', platform: nil)).to eq('stable')
    end
  end
end
