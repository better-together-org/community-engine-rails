# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::WebhookEndpointPolicy do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:owner_user) { create(:better_together_user, :confirmed) }
  let(:endpoint) { create(:better_together_webhook_endpoint, person: owner_user.person) }

  describe '#index?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, BetterTogether::WebhookEndpoint).index?).to be true
    end

    it 'denies regular users' do
      expect(described_class.new(regular_user, BetterTogether::WebhookEndpoint).index?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, BetterTogether::WebhookEndpoint).index?).to be_falsey
    end
  end

  describe '#show?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, endpoint).show?).to be true
    end

    it 'allows the endpoint owner' do
      expect(described_class.new(owner_user, endpoint).show?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, endpoint).show?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, endpoint).show?).to be_falsey
    end
  end

  describe '#create?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, BetterTogether::WebhookEndpoint).create?).to be true
    end

    it 'denies regular users' do
      expect(described_class.new(regular_user, BetterTogether::WebhookEndpoint).create?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, BetterTogether::WebhookEndpoint).create?).to be_falsey
    end
  end

  describe '#update?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, endpoint).update?).to be true
    end

    it 'allows the endpoint owner' do
      expect(described_class.new(owner_user, endpoint).update?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, endpoint).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, endpoint).destroy?).to be true
    end

    it 'allows the endpoint owner' do
      expect(described_class.new(owner_user, endpoint).destroy?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, endpoint).destroy?).to be false
    end
  end

  describe '#test?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, endpoint).test?).to be true
    end

    it 'allows the endpoint owner' do
      expect(described_class.new(owner_user, endpoint).test?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, endpoint).test?).to be false
    end
  end

  describe 'Scope' do
    let!(:manager_endpoint) { create(:better_together_webhook_endpoint, person: platform_manager_user.person) }
    let!(:owner_endpoint) { create(:better_together_webhook_endpoint, person: owner_user.person) }

    it 'returns all endpoints for platform managers' do
      scope = described_class::Scope.new(platform_manager_user, BetterTogether::WebhookEndpoint)
      expect(scope.resolve).to include(manager_endpoint, owner_endpoint)
    end

    it 'returns only own endpoints for regular users' do
      scope = described_class::Scope.new(owner_user, BetterTogether::WebhookEndpoint)
      result = scope.resolve
      expect(result).to include(owner_endpoint)
      expect(result).not_to include(manager_endpoint)
    end

    it 'returns no endpoints for unauthenticated users' do
      scope = described_class::Scope.new(nil, BetterTogether::WebhookEndpoint)
      expect(scope.resolve).to be_empty
    end
  end
end
