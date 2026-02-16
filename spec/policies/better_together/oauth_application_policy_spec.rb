# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::OauthApplicationPolicy do
  let(:platform_manager_user) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:owner_user) { create(:better_together_user, :confirmed) }
  let(:oauth_app) { create(:better_together_oauth_application, owner: owner_user.person) }

  describe '#index?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, BetterTogether::OauthApplication).index?).to be true
    end

    it 'denies regular users' do
      expect(described_class.new(regular_user, BetterTogether::OauthApplication).index?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, BetterTogether::OauthApplication)).not_to be_index
    end
  end

  describe '#show?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, oauth_app).show?).to be true
    end

    it 'allows the application owner' do
      expect(described_class.new(owner_user, oauth_app).show?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, oauth_app).show?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, oauth_app)).not_to be_show
    end
  end

  describe '#create?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, BetterTogether::OauthApplication).create?).to be true
    end

    it 'denies regular users' do
      expect(described_class.new(regular_user, BetterTogether::OauthApplication).create?).to be false
    end

    it 'denies unauthenticated users' do
      expect(described_class.new(nil, BetterTogether::OauthApplication)).not_to be_create
    end
  end

  describe '#update?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, oauth_app).update?).to be true
    end

    it 'allows the application owner' do
      expect(described_class.new(owner_user, oauth_app).update?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, oauth_app).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows platform managers' do
      expect(described_class.new(platform_manager_user, oauth_app).destroy?).to be true
    end

    it 'allows the application owner' do
      expect(described_class.new(owner_user, oauth_app).destroy?).to be true
    end

    it 'denies other regular users' do
      expect(described_class.new(regular_user, oauth_app).destroy?).to be false
    end
  end

  describe 'Scope' do
    let!(:manager_app) { create(:better_together_oauth_application, owner: platform_manager_user.person) }
    let!(:owner_app) { create(:better_together_oauth_application, owner: owner_user.person) }

    it 'returns all applications for platform managers' do
      scope = described_class::Scope.new(platform_manager_user, BetterTogether::OauthApplication)
      expect(scope.resolve).to include(manager_app, owner_app)
    end

    it 'returns only own applications for regular users' do
      scope = described_class::Scope.new(owner_user, BetterTogether::OauthApplication)
      result = scope.resolve
      expect(result).to include(owner_app)
      expect(result).not_to include(manager_app)
    end

    it 'returns no applications for unauthenticated users' do
      scope = described_class::Scope.new(nil, BetterTogether::OauthApplication)
      expect(scope.resolve).to be_empty
    end
  end
end
