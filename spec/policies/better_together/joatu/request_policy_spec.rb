# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::RequestPolicy, type: :policy do # rubocop:todo Metrics/BlockLength
  let(:creator_person) { create(:better_together_person) }
  let(:creator_user)   { create(:better_together_user, person: creator_person) }
  let(:manager_user)   { create(:better_together_user, :platform_manager) }
  let(:normal_user)    { create(:better_together_user) }

  let(:request_rec) { create(:better_together_joatu_request, creator: creator_person) }

  describe '#index?' do
    it { expect(described_class.new(normal_user, request_rec).index?).to eq true }
    it { expect(described_class.new(nil, request_rec).index?).to eq false }
  end

  describe '#show?' do
    it { expect(described_class.new(normal_user, request_rec).show?).to eq true }
    it { expect(described_class.new(nil, request_rec).show?).to eq false }
  end

  describe '#create?' do
    it { expect(described_class.new(normal_user, request_rec).create?).to eq true }
    it { expect(described_class.new(nil, request_rec).create?).to eq false }
  end

  describe '#update?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, request_rec).update?).to eq true
    end
    it 'allows a manager' do
      expect(described_class.new(manager_user, request_rec).update?).to eq true
    end
    it 'denies other users' do
      expect(described_class.new(normal_user, request_rec).update?).to eq false
    end
  end

  describe '#destroy?' do
    it 'allows the creator' do
      expect(described_class.new(creator_user, request_rec).destroy?).to eq true
    end
    it 'allows a manager' do
      expect(described_class.new(manager_user, request_rec).destroy?).to eq true
    end
    it 'denies other users' do
      expect(described_class.new(normal_user, request_rec).destroy?).to eq false
    end
  end

  describe 'Scope' do
    subject(:resolved) { described_class::Scope.new(user, BetterTogether::Joatu::Request).resolve }

    let!(:req1) { request_rec }
    let!(:req2) { create(:better_together_joatu_request) }

    context 'authenticated user' do
      let(:user) { normal_user }
      it 'includes all requests' do
        expect(resolved).to include(req1, req2)
      end
    end

    context 'guest' do
      let(:user) { nil }
      it 'returns none' do
        expect(resolved).to be_empty
      end
    end
  end
end
