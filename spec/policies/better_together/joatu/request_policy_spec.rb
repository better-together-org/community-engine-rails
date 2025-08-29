# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::RequestPolicy, type: :policy do
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user)   { create(:better_together_user, person: creator_person) }
  let(:manager_user)   { create(:better_together_user, :platform_manager) }
  let(:normal_user)    { create(:better_together_user) }

  let(:request_rec) { create(:better_together_joatu_request, creator: creator_person) }

  describe '#index?' do
    it { expect(described_class.new(normal_user, request_rec).index?).to be true }
    it { expect(described_class.new(nil, request_rec).index?).to be false }
  end

  describe '#show?' do
    it { expect(described_class.new(normal_user, request_rec).show?).to be true }
    it { expect(described_class.new(nil, request_rec).show?).to be false }
  end

  describe '#create?' do
    it { expect(described_class.new(normal_user, request_rec).create?).to be true }
    it { expect(described_class.new(nil, request_rec).create?).to be false }
  end

  describe '#update?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, request_rec).update?).to be true
    end

    it 'allows a manager' do
      expect(described_class.new(manager_user, request_rec).update?).to be true
    end

    it 'denies other users' do
      expect(described_class.new(normal_user, request_rec).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, request_rec).destroy?).to be true
    end

    it 'allows a manager' do
      expect(described_class.new(manager_user, request_rec).destroy?).to be true
    end

    it 'denies other users' do
      expect(described_class.new(normal_user, request_rec).destroy?).to be false
    end
  end

  describe 'Scope' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    subject(:resolved) { described_class::Scope.new(user, BetterTogether::Joatu::Request).resolve }

    let!(:req1) { request_rec } # rubocop:todo RSpec/IndexedLet
    let!(:req2) { create(:better_together_joatu_request) } # rubocop:todo RSpec/IndexedLet

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'authenticated user' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { normal_user }

      it 'includes all requests' do
        expect(resolved).to include(req1, req2)
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:todo RSpec/MultipleMemoizedHelpers
    context 'guest' do # rubocop:todo RSpec/ContextWording, RSpec/MultipleMemoizedHelpers
      let(:user) { nil }

      it 'returns none' do
        expect(resolved).to be_empty
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end
end
