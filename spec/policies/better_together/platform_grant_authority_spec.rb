# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformGrantAuthority, :skip_host_setup do
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:hosted_platform) { create(:better_together_platform, type: 'BetterTogether::HostedPlatform') }
  let(:steward_role) do
    BetterTogether::AccessControlBuilder.seed_data
    BetterTogether::Role.find_by!(identifier: 'platform_steward')
  end

  def steward_of(platform)
    user = create(:better_together_user, :confirmed)
    BetterTogether::PersonPlatformMembership.create!(
      joinable: platform, member: user.person, role: steward_role, status: 'active'
    )
    user
  end

  def grant_for(platform)
    build(:better_together_feature_access_grant, platform:)
  end

  def quota_grant_for(platform)
    build(:better_together_quota_grant, platform:)
  end

  before { host_platform }

  shared_examples 'grant authority' do |policy_class, builder|
    let(:policy_class) { policy_class }

    def allowed?(user, record)
      policy_class.new(user, record).create?
    end

    it 'lets a host steward configure the host platform itself' do
      expect(allowed?(steward_of(host_platform), send(builder, host_platform))).to be(true)
    end

    it 'lets a host steward configure a hosted platform with no operator' do
      expect(allowed?(steward_of(host_platform), send(builder, hosted_platform))).to be(true)
    end

    it 'denies a hosted steward configuring their own platform' do
      expect(allowed?(steward_of(hosted_platform), send(builder, hosted_platform))).to be(false)
    end

    it 'denies a steward of one hosted platform configuring another' do
      other = create(:better_together_platform, type: 'BetterTogether::HostedPlatform')
      expect(allowed?(steward_of(hosted_platform), send(builder, other))).to be(false)
    end

    it 'denies guests' do
      expect(allowed?(nil, send(builder, hosted_platform))).to be(false)
    end

    context 'with a local operator association in force' do
      let(:operator) { create(:better_together_platform, type: 'BetterTogether::OperatorPlatform') }
      let(:scopes) { %w[read billing] }

      before do
        create(:better_together_platform_association, :active,
               operator_platform: operator, managed_platform: hosted_platform, granted_scopes: scopes)
      end

      it 'lets the operator steward configure the managed platform' do
        expect(allowed?(steward_of(operator), send(builder, hosted_platform))).to be(true)
      end

      it 'denies the host steward who is not part of the operator' do
        expect(allowed?(steward_of(host_platform), send(builder, hosted_platform))).to be(false)
      end

      it 'denies the managed platform steward' do
        expect(allowed?(steward_of(hosted_platform), send(builder, hosted_platform))).to be(false)
      end

      context 'without the billing scope' do
        let(:scopes) { %w[read support] }

        it 'denies the operator steward' do
          expect(allowed?(steward_of(operator), send(builder, hosted_platform))).to be(false)
        end
      end
    end

    context 'with a remote operator association in force' do
      before do
        create(:better_together_platform_association, :active, :remote_operator,
               managed_platform: hosted_platform, granted_scopes: %w[read billing])
      end

      it 'denies every steward on this instance, host steward included' do
        expect(allowed?(steward_of(host_platform), send(builder, hosted_platform))).to be(false)
        expect(allowed?(steward_of(hosted_platform), send(builder, hosted_platform))).to be(false)
      end
    end

    context 'when the association is revoked' do
      before { create(:better_together_platform_association, :revoked, managed_platform: hosted_platform) }

      it 'returns the platform to host governance' do
        expect(allowed?(steward_of(host_platform), send(builder, hosted_platform))).to be(true)
      end
    end
  end

  describe BetterTogether::FeatureAccessGrantPolicy do
    it_behaves_like 'grant authority', described_class, :grant_for
  end

  describe BetterTogether::QuotaGrantPolicy do
    it_behaves_like 'grant authority', described_class, :quota_grant_for
  end
end
