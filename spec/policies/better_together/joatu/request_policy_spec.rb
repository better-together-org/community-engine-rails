# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::RequestPolicy, type: :policy do
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user)   { create(:better_together_user, person: creator_person) }
  let(:steward_user)   { create(:better_together_user, :platform_steward) }
  let(:network_admin_user) { create(:better_together_user, :network_admin) }
  let(:normal_user) { create(:better_together_user) }

  let(:request_rec) { create(:better_together_joatu_request, creator: creator_person, privacy: 'private') }
  let(:connection_request) do
    create(:better_together_joatu_connection_request, creator: creator_person)
  end

  describe '#index?' do
    it { expect(described_class.new(normal_user, request_rec).index?).to be true }
    it { expect(described_class.new(nil, request_rec).index?).to be false }
  end

  describe '#show?' do
    it { expect(described_class.new(normal_user, request_rec).show?).to be false }
    it { expect(described_class.new(nil, request_rec).show?).to be false }

    it 'allows viewing a public request' do
      request_rec.update_column(:privacy, 'public')
      expect(described_class.new(normal_user, request_rec).show?).to be true
    end
  end

  describe '#create?' do
    it { expect(described_class.new(normal_user, request_rec).create?).to be true }
    it { expect(described_class.new(nil, request_rec).create?).to be false }

    it 'requires network permissions for connection requests' do
      expect(described_class.new(normal_user, connection_request).create?).to be false
      expect(described_class.new(network_admin_user, connection_request).create?).to be true
    end
  end

  describe '#update?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, request_rec).update?).to be true
    end

    it 'allows a steward' do
      expect(described_class.new(steward_user, request_rec).update?).to be true
    end

    it 'denies other users' do
      expect(described_class.new(normal_user, request_rec).update?).to be false
    end

    it 'requires network permissions for connection requests' do
      expect(described_class.new(creator_user, connection_request).update?).to be false
      expect(described_class.new(network_admin_user, connection_request).update?).to be true
    end
  end

  describe '#destroy?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, request_rec).destroy?).to be true
    end

    it 'allows a steward' do
      expect(described_class.new(steward_user, request_rec).destroy?).to be true
    end

    it 'denies other users' do
      expect(described_class.new(normal_user, request_rec).destroy?).to be false
    end

    it 'requires network permissions for connection requests' do
      expect(described_class.new(creator_user, connection_request).destroy?).to be false
      expect(described_class.new(network_admin_user, connection_request).destroy?).to be true
    end
  end

  describe 'Scope' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject(:resolved) { described_class::Scope.new(user, BetterTogether::Joatu::Request).resolve }

    let!(:owned_private_request) { request_rec } # rubocop:todo RSpec/IndexedLet
    let!(:public_request) do # rubocop:todo RSpec/IndexedLet
      create(:better_together_joatu_request, privacy: 'private').tap { |request| request.update_column(:privacy, 'public') }
    end
    let!(:other_private_request) { create(:better_together_joatu_request, privacy: 'private') } # rubocop:todo RSpec/IndexedLet

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'authenticated user' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }

      it 'includes public requests only when the user is unrelated' do
        expect(resolved).to include(public_request)
        expect(resolved).not_to include(owned_private_request)
        expect(resolved).not_to include(other_private_request)
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'guest' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:user) { nil }

      it 'returns none' do
        expect(resolved).to be_empty
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end
end
