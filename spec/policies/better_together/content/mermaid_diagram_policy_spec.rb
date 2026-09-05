# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::MermaidDiagramPolicy, type: :policy do
  let(:steward_user) { create(:better_together_user, :platform_steward) }
  let(:normal_user) { create(:better_together_user) }

  it 'inherits from Content::BlockPolicy' do
    expect(described_class.superclass).to eq(BetterTogether::Content::BlockPolicy)
  end

  describe '#create?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::Content::MermaidDiagram).create?).to be true
    end

    it 'denies normal user' do
      expect(described_class.new(normal_user, BetterTogether::Content::MermaidDiagram).create?).to be false
    end
  end

  describe '#show?' do
    it 'allows platform steward' do
      expect(described_class.new(steward_user, BetterTogether::Content::MermaidDiagram).show?).to be true
    end

    it 'denies guest' do
      expect(described_class.new(nil, BetterTogether::Content::MermaidDiagram).show?).to be false
    end
  end
end
