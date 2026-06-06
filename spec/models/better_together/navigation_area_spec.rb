# frozen_string_literal: true

# spec/models/better_together/navigation_area_spec.rb

require 'rails_helper'

RSpec.describe BetterTogether::NavigationArea do
  subject(:navigation_area) { build(:better_together_navigation_area) }

  describe 'Factory' do
    it 'has a valid factory' do
      expect(navigation_area).to be_valid
    end
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to belong_to(:navigable).optional }
    it { is_expected.to have_many(:navigation_items).dependent(:destroy) }
  end

  describe 'ActiveModel validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:style).is_at_most(255).allow_blank }

    describe 'name uniqueness per platform' do
      let(:platform_a) { create(:better_together_platform, host: false) }
      let(:platform_b) { create(:better_together_platform, host: false) }
      let(:shared_name) { "Nav Area #{SecureRandom.hex(4)}" }

      it 'rejects duplicate name on the same platform' do
        create(:better_together_navigation_area, name: shared_name, platform: platform_a)
        dup = build(:better_together_navigation_area, name: shared_name, platform: platform_a)
        expect(dup).not_to be_valid
        expect(dup.errors[:name]).to be_present
      end

      it 'allows the same name on different platforms' do
        create(:better_together_navigation_area, name: shared_name, platform: platform_a)
        cross = build(:better_together_navigation_area, name: shared_name, platform: platform_b)
        expect(cross).to be_valid
      end
    end
  end

  it_behaves_like 'platform scoped identifier', factory: :better_together_navigation_area

  describe 'Attributes' do
    it { is_expected.to respond_to(:name) }
    it { is_expected.to respond_to(:style) }
    it { is_expected.to respond_to(:visible) }
    it { is_expected.to respond_to(:slug) }
    it { is_expected.to respond_to(:navigable_type) }
    it { is_expected.to respond_to(:navigable_id) }
    it { is_expected.to respond_to(:protected) }
  end

  describe 'Scopes' do
    describe '.visible' do
      it 'returns only visible navigation areas' do
        visible_area_count = described_class.visible.count
        create(:better_together_navigation_area, visible: false)
        expect(described_class.visible.count).to eq(visible_area_count)
      end
    end
  end

  # Add tests for any additional model logic or methods
end
