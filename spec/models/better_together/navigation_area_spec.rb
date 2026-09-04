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

  describe '#build_page_navigation_items' do
    # build_page_navigation_items only ever builds nav items for the
    # built-in seeded pages (header/footer static pages), so it always
    # marks them seed_privacy_ceiling_exempt -- see
    # NavigationItem#privacy_ceiling_exempt?.
    let(:navigation_area) { build(:better_together_navigation_area) }
    let(:public_page) { build(:better_together_page, privacy: 'public', title: 'About') }

    it 'marks each built page nav item seed-exempt from the privacy ceiling' do
      navigation_area.build_page_navigation_items([public_page])

      item = navigation_area.navigation_items.first
      expect(item.seed_privacy_ceiling_exempt).to be true
      expect(item.privacy).to eq('public')
    end
  end

  describe 'privacy ceiling enforcement (NavigationItem)' do
    # Platform factory defaults to privacy: 'private' -> ceiling 'community'.
    let(:private_platform) { create(:better_together_platform, host: false) }

    it 'is exempt under a non-public platform when explicitly seed-exempt' do
      item = build(:better_together_navigation_item, platform: private_platform, privacy: 'public',
                                                     seed_privacy_ceiling_exempt: true)

      expect(item).to be_valid
    end

    it 'is still bound by the ceiling when not seed-exempt, even if protected' do
      item = build(:better_together_navigation_item, platform: private_platform, protected: true, privacy: 'public')

      expect(item).not_to be_valid
      expect(item.errors[:privacy]).to be_present
    end
  end

  # Add tests for any additional model logic or methods
end
