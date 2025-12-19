# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::ReportPolicy, type: :policy do
  subject(:policy) { described_class.new(user, %i[metrics report]) }

  let(:user) { create(:user) }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }

  before do
    configure_host_platform
    BetterTogether::AccessControlBuilder.seed_data
  end

  describe '#index?' do
    context 'when user is analytics viewer' do
      before do
        role = BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer')
        BetterTogether::PersonPlatformMembership.create!(
          joinable: platform,
          member: user.person,
          role: role
        )
      end

      it 'allows access' do
        expect(policy.index?).to be true
      end
    end

    context 'when user is platform manager' do
      before do
        role = BetterTogether::Role.find_by(identifier: 'platform_manager')
        BetterTogether::PersonPlatformMembership.create!(
          joinable: platform,
          member: user.person,
          role: role
        )
      end

      it 'allows access' do
        expect(policy.index?).to be true
      end
    end

    context 'when user has no metrics permissions' do
      it 'denies access' do
        expect(policy.index?).to be false
      end
    end

    context 'when user is not authenticated' do
      let(:user) { nil }

      it 'denies access' do
        expect(policy.index?).to be false
      end
    end
  end

  describe '#show?' do
    context 'when user is analytics viewer' do
      before do
        role = BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer')
        BetterTogether::PersonPlatformMembership.create!(
          joinable: platform,
          member: user.person,
          role: role
        )
      end

      it 'allows access' do
        expect(policy.show?).to be true
      end
    end

    context 'when user has no permissions' do
      it 'denies access' do
        expect(policy.show?).to be false
      end
    end
  end

  describe '#create?' do
    context 'when user has create_metrics_reports permission' do
      before do
        role = BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer')
        BetterTogether::PersonPlatformMembership.create!(
          joinable: platform,
          member: user.person,
          role: role
        )
      end

      it 'allows access' do
        expect(policy.create?).to be true
      end
    end

    context 'when user has no permissions' do
      it 'denies access' do
        expect(policy.create?).to be false
      end
    end
  end

  describe '#download?' do
    context 'when user has download_metrics_reports permission' do
      before do
        role = BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer')
        BetterTogether::PersonPlatformMembership.create!(
          joinable: platform,
          member: user.person,
          role: role
        )
      end

      it 'allows access' do
        expect(policy.download?).to be true
      end
    end

    context 'when user has no permissions' do
      it 'denies access' do
        expect(policy.download?).to be false
      end
    end
  end
end
