# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::HubPolicy, type: :policy do
  let(:steward_user) { create(:better_together_user, :platform_steward) }
  let(:normal_user) { create(:better_together_user) }

  describe '#index?' do
    it 'allows platform steward (manage_platform permission)' do
      expect(described_class.new(steward_user, :hub).index?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, :hub).index?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, :hub).index?).to be false
    end
  end
end
