# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::HostJobsPolicy, type: :policy do
  subject(:policy) { described_class.new(user, :host_jobs) }

  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:user) { create(:user, :confirmed) }

  before do
    configure_host_platform
    Rails.cache.clear
  end

  def join(platform, role)
    BetterTogether::PersonPlatformMembership.create!(joinable: platform, member: user.person, role:, status: 'active')
  end

  def role_with(platform, identifiers)
    create(:better_together_role, :platform_role, platform:).tap do |role|
      role.assign_resource_permissions(identifiers)
    end
  end

  context 'with the platform steward role on the host platform' do
    before { join(host_platform, HostRoles.find('platform_steward')) }

    it 'allows the jobs screen, summary and Sidekiq', :aggregate_failures do
      expect(policy.show?).to be true
      expect(policy.summary?).to be true
      expect(policy.sidekiq?).to be true
    end
  end

  context 'with a role holding only manage_platform_jobs' do
    before { join(host_platform, role_with(host_platform, %w[manage_platform_jobs])) }

    it 'allows access' do
      expect(policy.show?).to be true
    end
  end

  context 'with manage_platform_settings but not manage_platform_jobs' do
    before { join(host_platform, role_with(host_platform, %w[manage_platform_settings])) }

    it 'denies access' do
      expect(policy.show?).to be false
    end
  end

  context 'with the steward role of another platform' do
    let(:other_platform) { create(:better_together_platform, locality: 'local') }

    before { join(other_platform, BetterTogether::Role.find_default('platform_steward', platform: other_platform)) }

    it 'denies access to the host jobs' do
      expect(policy.show?).to be false
    end
  end

  context 'with no platform role' do
    it 'denies access' do
      expect(policy.show?).to be false
    end
  end

  context 'when anonymous' do
    let(:user) { nil }

    it 'denies access' do
      expect(policy.show?).to be false
    end
  end
end
