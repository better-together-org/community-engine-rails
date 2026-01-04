# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::HostDashboardPolicy, type: :policy do
  subject(:policy) { described_class.new(user, :host_dashboard) }

  let(:user) { create(:user) }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }

  before do
    configure_host_platform
  end

  describe '#show?' do
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
        expect(policy.show?).to be true
      end
    end

    context 'when user is analytics viewer' do
      before do
        # Seed the analytics viewer role first
        BetterTogether::AccessControlBuilder.seed_data

        role = BetterTogether::Role.find_by(identifier: 'platform_analytics_viewer')
        BetterTogether::PersonPlatformMembership.create!(
          joinable: platform,
          member: user.person,
          role: role
        )
      end

      it 'denies access' do
        expect(policy.show?).to be false
      end
    end

    context 'when user has no platform roles' do
      it 'denies access' do
        expect(policy.show?).to be false
      end
    end

    context 'when user is not authenticated' do
      let(:user) { nil }

      it 'denies access' do
        expect(policy.show?).to be false
      end
    end
  end
end
