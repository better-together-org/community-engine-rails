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
  end
end
