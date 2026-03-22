# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformConnectionPolicy do
  subject(:policy) { described_class.new(user, platform_connection) }

  let(:platform_connection) { create(:better_together_platform_connection, :active) }
  let(:user) { nil }

  describe 'for a network admin' do
    let(:user) { create(:better_together_user, :network_admin) }

    it 'allows index, show, and update' do
      expect(policy.index?).to be true
      expect(policy.show?).to be true
      expect(policy.update?).to be true
    end
  end

  describe 'for a regular user' do
    let(:user) { create(:better_together_user) }

    it 'denies index, show, and update' do
      expect(policy.index?).to be false
      expect(policy.show?).to be false
      expect(policy.update?).to be false
    end
  end
end
