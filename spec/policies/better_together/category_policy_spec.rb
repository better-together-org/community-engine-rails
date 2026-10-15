# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::CategoryPolicy, type: :policy do
  let(:steward_user) { create(:better_together_user, :platform_steward) }
  let(:normal_user) { create(:better_together_user) }

  describe '#index?' do
    it 'allows platform steward (platform_taxonomy_manager?)' do
      expect(described_class.new(steward_user, BetterTogether::Category).index?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::Category).index?).to be false
    end

    it 'denies guest' do
      expect(described_class.new(nil, BetterTogether::Category).index?).to be false
    end
  end

  describe '#create?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::Category).create?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::Category).create?).to be false
    end
  end

  describe '#show?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::Category).show?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::Category).show?).to be false
    end
  end

  describe '#update?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::Category).update?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::Category).update?).to be false
    end
  end

  describe '#download? (attached media)' do
    let(:viewer) { create(:better_together_user, :confirmed) }

    it 'matches #show? for a public record, for anonymous and signed-in viewers', :aggregate_failures do
      record = create(:category, privacy: 'public')

      [nil, viewer].each do |agent|
        policy = described_class.new(agent, record)
        expect(policy.download?).to eq(policy.show?)
      end
    end

    it 'is refused to a signed-in viewer who cannot see a private record', :aggregate_failures do
      record = create(:category, privacy: 'private')
      policy = described_class.new(viewer, record)

      expect(policy.show?).to be false
      expect(policy.download?).to be false
    end
  end
end
