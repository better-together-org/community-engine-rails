# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Platform do
  describe 'feature gates' do
    describe '#feature_rollout_for' do
      let(:platform) { build(:better_together_platform) }

      it 'returns feature registry default when no rollout override is set' do
        rollout = platform.feature_rollout_for(:new_content_blocks)
        registry_default = BetterTogether::FeatureRegistry.find(:new_content_blocks).fetch(:default_rollout)

        expect(rollout).to eq(registry_default)
      end

      it 'returns platform-specific override when set' do
        platform.settings = { feature_gate_rollouts: { new_content_blocks: 'alpha' } }

        expect(platform.feature_rollout_for(:new_content_blocks)).to eq('alpha')
      end

      it 'falls back to registry default when override is removed' do
        platform.settings = { feature_gate_rollouts: {} }

        rollout = platform.feature_rollout_for(:new_content_blocks)
        registry_default = BetterTogether::FeatureRegistry.find(:new_content_blocks).fetch(:default_rollout)

        expect(rollout).to eq(registry_default)
      end

      it 'handles nil settings gracefully' do
        platform.settings = nil

        rollout = platform.feature_rollout_for(:new_content_blocks)
        registry_default = BetterTogether::FeatureRegistry.find(:new_content_blocks).fetch(:default_rollout)

        expect(rollout).to eq(registry_default)
      end

      it 'handles unknown feature keys' do
        platform.settings = { feature_gate_rollouts: { unknown_feature: 'beta' } }

        # Should not raise; just return registry default or raise FeatureRegistry::NotFound
        expect { platform.feature_rollout_for(:new_content_blocks) }
          .not_to raise_error
      end
    end

    describe BetterTogether::Platform, '#feature_gate_rollouts=' do
      let(:platform) { build(:better_together_platform) }

      it 'sanitizes feature_gate_rollouts to reject unknown features' do
        platform.feature_gate_rollouts = {
          new_content_blocks: 'beta',
          unknown_feature: 'beta'
        }

        sanitized = platform.feature_gate_rollouts
        expect(sanitized).to include('new_content_blocks' => 'beta')
        expect(sanitized).not_to include('unknown_feature')
      end

      it 'rejects invalid rollout values' do
        platform.feature_gate_rollouts = {
          new_content_blocks: 'invalid_rollout'
        }

        sanitized = platform.feature_gate_rollouts
        # Invalid rollout should be stripped or replaced with default
        expect(sanitized['new_content_blocks']).not_to eq('invalid_rollout')
      end

      it 'accepts valid rollout values (stable, beta, alpha, off)' do
        %w[stable beta alpha off].each do |rollout|
          platform.feature_gate_rollouts = { new_content_blocks: rollout }

          expect(platform.feature_gate_rollouts['new_content_blocks']).to eq(rollout)
        end
      end
    end

    describe BetterTogether::FeatureGate, '.enabled?' do
      let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, host: true) }
      let(:other_platform) { create(:better_together_platform) }
      let(:user) { create(:better_together_user) }
      let(:person) { user.person }

      context 'with stable rollout' do
        before do
          host_platform.update!(feature_gate_rollouts: { new_content_blocks: 'stable' })
        end

        it 'returns true for all users' do
          expect(
            described_class.enabled?(:new_content_blocks, actor: person, platform: host_platform)
          ).to be(true)
        end
      end

      context 'with alpha rollout' do
        before do
          host_platform.update!(feature_gate_rollouts: { new_content_blocks: 'alpha' })
        end

        it 'returns false for users without alpha access' do
          expect(
            described_class.enabled?(:new_content_blocks, actor: person, platform: host_platform)
          ).to be(false)
        end

        it 'returns true for users with alpha permission' do
          # Grant alpha access via role
          alpha_role = create(:better_together_role, identifier: 'test_alpha_role', resource_type: 'BetterTogether::Platform')
          alpha_permission = BetterTogether::ResourcePermission.find_by(identifier: 'access_alpha_features') ||
                             create(:better_together_resource_permission, identifier: 'access_alpha_features')
          alpha_role.resource_permissions << alpha_permission

          BetterTogether::PersonPlatformMembership.find_or_create_by!(
            joinable: host_platform,
            member: person
          ) do |membership|
            membership.role = alpha_role
            membership.status = 'active'
          end.update!(role: alpha_role, status: 'active')

          expect(
            described_class.enabled?(:new_content_blocks, actor: person, platform: host_platform)
          ).to be(true)
        end

        it 'returns true for users with explicit alpha grant' do
          create(:better_together_feature_access_grant,
                 platform: host_platform,
                 person:,
                 feature_key: 'new_content_blocks',
                 access_level: 'alpha')

          expect(
            described_class.enabled?(:new_content_blocks, actor: person, platform: host_platform)
          ).to be(true)
        end
      end

      context 'with beta rollout' do
        before do
          host_platform.update!(feature_gate_rollouts: { new_content_blocks: 'beta' })
        end

        it 'returns false for users without beta access' do
          expect(
            described_class.enabled?(:new_content_blocks, actor: person, platform: host_platform)
          ).to be(false)
        end

        it 'returns true for users with beta permission' do
          # Grant beta access via role
          beta_role = create(:better_together_role, identifier: 'test_beta_role', resource_type: 'BetterTogether::Platform')
          beta_permission = BetterTogether::ResourcePermission.find_by(identifier: 'access_beta_features') ||
                            create(:better_together_resource_permission, identifier: 'access_beta_features')
          beta_role.resource_permissions << beta_permission

          BetterTogether::PersonPlatformMembership.find_or_create_by!(
            joinable: host_platform,
            member: person
          ) do |membership|
            membership.role = beta_role
            membership.status = 'active'
          end.update!(role: beta_role, status: 'active')

          expect(
            described_class.enabled?(:new_content_blocks, actor: person, platform: host_platform)
          ).to be(true)
        end
      end

      context 'with off rollout' do
        before do
          host_platform.update!(feature_gate_rollouts: { new_content_blocks: 'off' })
        end

        it 'returns false for all users by default' do
          expect(
            described_class.enabled?(:new_content_blocks, actor: person, platform: host_platform)
          ).to be(false)
        end

        it 'returns true only for users with explicit grant' do
          create(:better_together_feature_access_grant,
                 platform: host_platform,
                 person:,
                 feature_key: 'new_content_blocks',
                 access_level: 'alpha')

          expect(
            described_class.enabled?(:new_content_blocks, actor: person, platform: host_platform)
          ).to be(true)
        end
      end

      context 'with different platforms' do
        before do
          host_platform.update!(feature_gate_rollouts: { new_content_blocks: 'stable' })
          other_platform.update!(feature_gate_rollouts: { new_content_blocks: 'off' })
        end

        it 'respects per-platform rollout settings' do
          # Same user, different rollouts on each platform
          expect(
            described_class.enabled?(:new_content_blocks, actor: person, platform: host_platform)
          ).to be(true)

          expect(
            described_class.enabled?(:new_content_blocks, actor: person, platform: other_platform)
          ).to be(false)
        end

        it 'falls back to host platform when platform is nil' do
          host_platform.update!(feature_gate_rollouts: { new_content_blocks: 'stable' })

          expect(
            described_class.enabled?(:new_content_blocks, actor: person, platform: nil)
          ).to be(true)
        end
      end
    end

    describe BetterTogether::FeatureAccessGrant do
      let(:platform) { create(:better_together_platform) }
      let(:person) { create(:better_together_person) }

      describe 'scoped to platform' do
        let(:platform_alpha_grant) do
          create(:better_together_feature_access_grant,
                 platform:,
                 person:,
                 feature_key: 'new_content_blocks',
                 access_level: 'alpha')
        end

        let(:other_platform) { create(:better_together_platform) }
        let(:platform_beta_grant) do
          create(:better_together_feature_access_grant,
                 platform: other_platform,
                 person:,
                 feature_key: 'new_content_blocks',
                 access_level: 'beta')
        end

        it 'allows same person with different access levels per platform' do
          platform_alpha_grant
          platform_beta_grant

          grants_on_platform = described_class.where(
            platform:,
            person:,
            feature_key: 'new_content_blocks'
          )

          expect(grants_on_platform.count).to eq(1)
          expect(grants_on_platform.first.access_level).to eq('alpha')
        end

        it 'enforces uniqueness constraint per platform' do
          platform_alpha_grant

          # Attempting to create a duplicate grant should fail or update
          expect do
            create(:better_together_feature_access_grant,
                   platform:,
                   person:,
                   feature_key: 'new_content_blocks',
                   access_level: 'beta')
          end.to raise_error(ActiveRecord::RecordInvalid)
        end
      end

      describe 'expiration' do
        it 'is active when expires_at is in the future' do
          grant = create(:better_together_feature_access_grant,
                         platform:,
                         person:,
                         expires_at: 1.day.from_now)

          expect(grant.active_now?).to be(true)
        end

        it 'is inactive when expires_at is in the past' do
          grant = create(:better_together_feature_access_grant,
                         platform:,
                         person:,
                         expires_at: 1.day.ago)

          expect(grant.active_now?).to be(false)
        end

        it 'is active when expires_at is nil (no expiration)' do
          grant = create(:better_together_feature_access_grant,
                         platform:,
                         person:,
                         expires_at: nil)

          expect(grant.active_now?).to be(true)
        end
      end

      describe 'revocation' do
        it 'marks grant as revoked' do
          grant = create(:better_together_feature_access_grant,
                         platform:,
                         person:)

          grant.revoke!
          expect(grant.revoked_at).to be_present
          expect(grant.active_now?).to be(false)
        end

        it 'is not included in active scope when revoked' do
          grant = create(:better_together_feature_access_grant,
                         platform:,
                         person:,
                         feature_key: 'new_content_blocks')

          grant.revoke!

          active_grants = described_class.active.where(
            person:,
            feature_key: 'new_content_blocks'
          )

          expect(active_grants).not_to include(grant)
        end
      end
    end
  end
end
