# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Fleet::Node do
  subject(:node) { build(:better_together_fleet_node) }

  describe 'associations' do
    it { is_expected.to belong_to(:platform).optional }
    it { is_expected.to have_one(:node_ownership).class_name('BetterTogether::Fleet::NodeOwnership') }
    it { is_expected.to have_many(:c3_tokens).class_name('BetterTogether::C3::Token') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:node_id) }
    it { is_expected.to validate_presence_of(:node_category) }
    it { is_expected.to validate_uniqueness_of(:node_id) }

    it 'is valid with required attributes' do
      expect(node).to be_valid
    end

    it 'rejects an invalid node_category' do
      node.node_category = 'invalid'
      expect(node).not_to be_valid
      expect(node.errors[:node_category]).to be_present
    end

    it 'accepts all valid node_categories' do
      described_class::NODE_CATEGORIES.each do |category|
        node.node_category = category
        expect(node).to be_valid
      end
    end

    it 'accepts a nil safety_tier' do
      node.safety_tier = nil
      expect(node).to be_valid
    end

    it 'rejects an invalid safety_tier' do
      node.safety_tier = 'T9'
      expect(node).not_to be_valid
      expect(node.errors[:safety_tier]).to be_present
    end

    it 'accepts all valid safety tiers' do
      described_class::SAFETY_TIERS.each do |tier|
        node.safety_tier = tier
        expect(node).to be_valid
      end
    end
  end

  describe '#gpu_type' do
    context 'when hardware has no gpu_type key' do
      it 'defaults to cpu' do
        node.hardware = {}
        expect(node.gpu_type).to eq('cpu')
      end
    end

    context 'when hardware specifies a gpu_type' do
      it 'returns the configured gpu_type' do
        node.hardware = { 'gpu_type' => 'cuda' }
        expect(node.gpu_type).to eq('cuda')
      end
    end
  end

  describe '#gpu_capable?' do
    it 'returns true for cuda' do
      node.hardware = { 'gpu_type' => 'cuda' }
      expect(node.gpu_capable?).to be true
    end

    it 'returns true for metal' do
      node.hardware = { 'gpu_type' => 'metal' }
      expect(node.gpu_capable?).to be true
    end

    it 'returns true for adreno' do
      node.hardware = { 'gpu_type' => 'adreno' }
      expect(node.gpu_capable?).to be true
    end

    it 'returns false for cpu (default)' do
      node.hardware = {}
      expect(node.gpu_capable?).to be false
    end

    it 'returns false for an unknown gpu_type' do
      node.hardware = { 'gpu_type' => 'unknown_accel' }
      expect(node.gpu_capable?).to be false
    end
  end

  describe '#mark_online!' do
    let(:saved_node) { create(:better_together_fleet_node) }

    it 'sets online to true' do
      saved_node.mark_online!
      expect(saved_node.reload.online).to be true
    end

    it 'sets last_seen_at to current time' do
      freeze_time do
        saved_node.mark_online!
        expect(saved_node.reload.last_seen_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe '#mark_offline!' do
    let(:saved_node) { create(:better_together_fleet_node, :online) }

    it 'sets online to false' do
      saved_node.mark_offline!
      expect(saved_node.reload.online).to be false
    end
  end

  describe 'scopes' do
    before do
      create(:better_together_fleet_node, :online, node_id: 'online-node')
      create(:better_together_fleet_node, node_id: 'offline-node', online: false)
    end

    it '.online returns only online nodes' do
      expect(described_class.online.map(&:node_id)).to include('online-node')
      expect(described_class.online.map(&:node_id)).not_to include('offline-node')
    end

    it '.cat1 returns only cat1 nodes' do
      cat2_node = create(:better_together_fleet_node, :cat2, node_id: 'cat2-node')
      expect(described_class.cat1).not_to include(cat2_node)
    end
  end

  describe 'factory traits' do
    it 'creates a cuda GPU node with :with_cuda_gpu trait' do
      gpu_node = create(:better_together_fleet_node, :with_cuda_gpu)
      expect(gpu_node.gpu_capable?).to be true
      expect(gpu_node.gpu_type).to eq('cuda')
    end

    it 'creates a metal GPU node with :with_metal_gpu trait' do
      gpu_node = create(:better_together_fleet_node, :with_metal_gpu)
      expect(gpu_node.gpu_capable?).to be true
      expect(gpu_node.gpu_type).to eq('metal')
    end
  end
end
