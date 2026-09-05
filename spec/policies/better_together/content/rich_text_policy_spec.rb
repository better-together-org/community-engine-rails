# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::RichTextPolicy, type: :policy do
  let(:steward_user) { create(:better_together_user, :platform_steward) }
  let(:normal_user) { create(:better_together_user) }

  it 'inherits from Content::BlockPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::Content::BlockPolicy)
  end

  describe '#create?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::Content::RichText).create?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::Content::RichText).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::Content::RichText).update?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, BetterTogether::Content::RichText).update?).to be false
    end
  end
end
