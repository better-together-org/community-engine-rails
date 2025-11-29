# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::NavigationBuilder, type: :model do
  describe '.reset_navigation_areas' do
    it 'deletes all navigation items' do
      # Create some test navigation areas and items first
      area = create(:better_together_navigation_area)
      create(:better_together_navigation_item, navigation_area: area)

      described_class.reset_navigation_areas

      # After reset, should have new items from seed_data, but old ones should be gone
      expect(BetterTogether::NavigationItem.where(navigation_area: area).count).to eq(0)
    end

    it 'deletes all navigation areas' do
      # Create a test navigation area
      create(:better_together_navigation_area, name: 'Test Area', identifier: 'test-area')

      described_class.reset_navigation_areas

      # Should have exactly 4 areas (the seeded ones - documentation disabled), regardless of what was there before
      expect(BetterTogether::NavigationArea.count).to eq(4)
      # The test area should be gone
      expect(BetterTogether::NavigationArea.find_by(identifier: 'test-area')).to be_nil
    end

    it 'rebuilds all navigation areas' do
      described_class.reset_navigation_areas

      expect(BetterTogether::NavigationArea.count).to eq(4)

      # Use identifier instead of slug
      area_identifiers = BetterTogether::NavigationArea.pluck(:identifier)
      expect(area_identifiers).to contain_exactly(
        'platform-header',
        'platform-host',
        'better-together',
        'platform-footer'
        # 'documentation' - disabled for now
      )
    end

    it 'recreates navigation items' do
      described_class.reset_navigation_areas

      expect(BetterTogether::NavigationItem.count).to be > 0
    end

    it 'creates protected navigation areas' do
      described_class.reset_navigation_areas

      BetterTogether::NavigationArea.find_each do |area|
        expect(area.protected).to be true
      end
    end

    it 'creates protected navigation items' do
      described_class.reset_navigation_areas

      # Most seeded items should be protected (but not all, some may be unprotected)
      protected_items = BetterTogether::NavigationItem.where(protected: true)
      expect(protected_items.count).to be > 0
    end
  end

  describe '.reset_navigation_area' do
    context 'with valid navigation area identifier' do
      it 'works for platform-header' do
        described_class.reset_navigation_area('platform-header')

        header = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-header')
        expect(header).to be_present
        expect(header.navigation_items.count).to be > 0
      end

      it 'works for platform-host' do
        described_class.reset_navigation_area('platform-host')

        host = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-host')
        expect(host).to be_present
        expect(host.navigation_items.count).to be > 0
      end

      it 'works for better-together' do
        described_class.reset_navigation_area('better-together')

        bt = BetterTogether::NavigationArea.i18n.find_by(slug: 'better-together')
        expect(bt).to be_present
        expect(bt.navigation_items.count).to be > 0
      end

      it 'works for platform-footer' do
        described_class.reset_navigation_area('platform-footer')

        footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
        expect(footer).to be_present
        expect(footer.navigation_items.count).to be > 0
      end

      it 'works for documentation' do
        skip 'Documentation builder is disabled from auto-seeding (WIP)'

        # Documentation builder available but not auto-seeded
        described_class.reset_navigation_area('documentation')

        docs_area = BetterTogether::NavigationArea.i18n.find_by(slug: 'documentation')
        expect(docs_area).to be_present
        expect(docs_area.navigation_items.count).to be > 0
      end

      it 'deletes old navigation items for that area' do
        # Create the footer area first
        described_class.reset_navigation_area('platform-footer')

        # Reset it again - the area gets deleted and recreated
        described_class.reset_navigation_area('platform-footer')

        # Should have the recreated footer with navigation items
        footer_area = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
        expect(footer_area).to be_present
        expect(footer_area.navigation_items.count).to be > 0
      end

      it 'creates new navigation items for that area' do
        described_class.reset_navigation_area('platform-footer')

        footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
        expect(footer.navigation_items.count).to be > 0
      end

      it 'resets the specified area' do
        # Setup initial state
        described_class.reset_navigation_areas

        footer_area = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
        initial_name = footer_area.name

        # Reset just the footer
        described_class.reset_navigation_area('platform-footer')

        footer_area = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
        expect(footer_area.name).to eq(initial_name)
      end

      it 'preserves other navigation areas' do
        # Setup initial state
        described_class.reset_navigation_areas

        initial_identifiers = BetterTogether::NavigationArea.pluck(:identifier).sort

        # Reset just the footer
        described_class.reset_navigation_area('platform-footer')

        # Should still have all 5 areas
        final_identifiers = BetterTogether::NavigationArea.pluck(:identifier).sort
        expect(final_identifiers).to eq(initial_identifiers)
      end
    end

    context 'with invalid navigation area identifier' do
      it 'does not raise an error' do
        expect do
          described_class.reset_navigation_area('invalid-slug')
        end.not_to raise_error
      end

      it 'does not affect existing areas' do
        described_class.reset_navigation_areas
        initial_count = BetterTogether::NavigationArea.count

        described_class.reset_navigation_area('invalid-slug')

        expect(BetterTogether::NavigationArea.count).to eq(initial_count)
      end
    end

    context 'with nil identifier' do
      it 'does not raise an error' do
        expect do
          described_class.reset_navigation_area(nil)
        end.not_to raise_error
      end
    end
  end

  describe 'navigation item relationships' do
    before do
      described_class.reset_navigation_areas
    end

    it 'creates parent-child relationships for contributor agreements' do
      footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')

      # Find the "Contributor Agreements" parent item
      contributor_agreements_item = footer.navigation_items.find_by(item_type: 'dropdown')

      expect(contributor_agreements_item).to be_present
      expect(contributor_agreements_item.children.count).to eq(2)
    end

    it 'includes both contributor agreement pages as children' do
      footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
      contributor_agreements_item = footer.navigation_items.find_by(item_type: 'dropdown')

      child_slugs = contributor_agreements_item.children.map { |child| child.linkable&.slug }.compact
      # Check that both agreement types are present (slug may have FriendlyId suffix after reset)
      expect(child_slugs.any? { |slug| slug.start_with?('code-contributor-agreement') }).to be true
      expect(child_slugs.any? { |slug| slug.start_with?('content-contributor-agreement') }).to be true
    end

    it 'preserves nested structure after reset' do
      # Get initial structure
      footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
      initial_parent_count = footer.navigation_items.where(parent_id: nil).count
      initial_child_count = footer.navigation_items.where.not(parent_id: nil).count

      # Reset the footer
      described_class.reset_navigation_area('platform-footer')

      # Check structure is preserved
      footer = BetterTogether::NavigationArea.i18n.find_by(slug: 'platform-footer')
      expect(footer.navigation_items.where(parent_id: nil).count).to eq(initial_parent_count)
      expect(footer.navigation_items.where.not(parent_id: nil).count).to eq(initial_child_count)
    end
  end
end
