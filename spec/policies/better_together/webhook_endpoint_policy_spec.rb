# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::WebhookEndpointPolicy do
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
  end

  let(:platform_api_user) { create(:better_together_user, :confirmed) }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:owner_user) { create(:better_together_user, :confirmed) }
  let(:endpoint) { create(:better_together_webhook_endpoint, person: owner_user.person) }

  before do
    grant_platform_permission(platform_api_user, 'manage_platform_api')
  end

  describe '#index?' do
    it 'allows explicit API managers' do
      expect(described_class.new(platform_api_user, BetterTogether::WebhookEndpoint).index?).to be true
    end

    it 'denies regular users' do
      expect(described_class.new(regular_user, BetterTogether::WebhookEndpoint).index?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, BetterTogether::WebhookEndpoint)).not_to be_index
    end
  end

  describe '#show?' do
    it 'allows explicit API managers' do
      expect(described_class.new(platform_api_user, endpoint).show?).to be true
    end

    it 'allows the endpoint owner' do
      expect(described_class.new(owner_user, endpoint).show?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, endpoint).show?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, endpoint)).not_to be_show
    end
  end

  describe '#create?' do
    it 'allows explicit API managers' do
      expect(described_class.new(platform_api_user, BetterTogether::WebhookEndpoint).create?).to be true
    end

    it 'denies regular users' do
      expect(described_class.new(regular_user, BetterTogether::WebhookEndpoint).create?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, BetterTogether::WebhookEndpoint)).not_to be_create
    end
  end

  describe '#update?' do
    it 'allows explicit API managers' do
      expect(described_class.new(platform_api_user, endpoint).update?).to be true
    end

    it 'allows the endpoint owner' do
      expect(described_class.new(owner_user, endpoint).update?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, endpoint).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows explicit API managers' do
      expect(described_class.new(platform_api_user, endpoint).destroy?).to be true
    end

    it 'allows the endpoint owner' do
      expect(described_class.new(owner_user, endpoint).destroy?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, endpoint).destroy?).to be false
    end
  end

  describe '#test?' do
    it 'allows explicit API managers' do
      expect(described_class.new(platform_api_user, endpoint).test?).to be true
    end

    it 'allows the endpoint owner' do
      expect(described_class.new(owner_user, endpoint).test?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, endpoint).test?).to be false
    end
  end

  describe 'Scope' do
    let!(:manager_endpoint) { create(:better_together_webhook_endpoint, person: platform_api_user.person) }
    let!(:owner_endpoint) { create(:better_together_webhook_endpoint, person: owner_user.person) }

    it 'returns all endpoints for explicit API managers' do
      scope = described_class::Scope.new(platform_api_user, BetterTogether::WebhookEndpoint)
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
