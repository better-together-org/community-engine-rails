# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::HostDashboardPolicy, type: :policy do
  subject(:policy) { described_class.new(user, nil) }

  context 'when user can manage platform' do
    let(:user) { create(:user, :confirmed, :platform_manager) }

    it 'permits access' do
      expect(policy.index?).to be(true)
    end
  end

  context 'when user cannot manage platform' do
    let(:user) { create(:user, :confirmed) }

    it 'denies access' do
      expect(policy.index?).to be(false)
    end
  end

  context 'when no user is present' do
    let(:user) { nil }

    it 'denies access' do
      expect(policy.index?).to be(false)
    end
  end
end
