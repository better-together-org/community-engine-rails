# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Fleet::NodeOwnership do
  subject(:ownership) { described_class.new(node: node, owner: person) }

  let(:node) { create(:better_together_fleet_node) }
  let(:person) { create(:better_together_person) }

  describe 'validations' do
    it 'is valid with a node and owner' do
      expect(ownership).to be_valid
    end

    it 'requires unique node_id (one ownership per node)' do
      described_class.create!(node: node, owner: person)
      expect(ownership).not_to be_valid
      expect(ownership.errors[:node_id]).to be_present
    end
  end

  describe 'associations' do
    it 'belongs to a fleet node' do
      ownership = described_class.create!(node: node, owner: person)
      expect(ownership.node).to eq(node)
    end

    it 'belongs to a polymorphic owner' do
      ownership = described_class.create!(node: node, owner: person)
      expect(ownership.owner).to eq(person)
    end
  end
end
