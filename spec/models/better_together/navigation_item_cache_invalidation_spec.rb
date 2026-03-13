# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::NavigationItem do
  let(:navigation_area) { create(:better_together_navigation_area) }
  let(:page) { create(:better_together_page, title: 'Original Title') }
  let(:navigation_item) do
    create(:better_together_navigation_item,
           navigation_area:,
           linkable: page,
           title: 'Nav Item',
           visible: true,
           privacy: 'public',
           protected: false) # Allow destruction in tests
  end

  describe 'touching navigation_area' do
    context 'when navigation item is created' do
      it 'touches the navigation area to bust cache' do
        initial_timestamp = navigation_area.updated_at
        sleep 0.01 # Ensure timestamp difference

        create(:better_together_navigation_item, navigation_area:, visible: true, privacy: 'public')

        expect(navigation_area.reload.updated_at).to be > initial_timestamp
      end
    end

    context 'when navigation item is updated' do
      it 'touches the navigation area via belongs_to touch: true' do
        initial_timestamp = navigation_area.updated_at
        sleep 0.01

        navigation_item.update!(url: '/new-url')

        expect(navigation_area.reload.updated_at).to be > initial_timestamp
      end
    end

    context 'when navigation item title translation changes' do
      it 'touches the navigation area' do
        # Create own item to avoid lock_version conflicts with other tests
        item = create(:better_together_navigation_item,
                      navigation_area:,
                      linkable: page,
                      title: 'Nav Item',
                      visible: true,
                      privacy: 'public',
                      protected: false)
        initial_timestamp = navigation_area.updated_at
        sleep 0.01

        # Update without Mobility wrapper - let it use current locale
        item.title = 'Updated Nav Title'
        item.save!

        expect(navigation_area.reload.updated_at).to be > initial_timestamp
      end
    end

    context 'when navigation item is destroyed' do
      it 'touches the navigation area to bust cache' do
        navigation_item # Ensure it exists
        initial_timestamp = navigation_area.updated_at
        sleep 0.01

        result = navigation_item.destroy
        expect(result).to be_truthy, "Destroy returned #{result}, errors: #{navigation_item.errors.full_messages}"

        expect(navigation_area.reload.updated_at).to be > initial_timestamp
      end
    end

    context 'when linked page title changes' do
      it 'touches the navigation item and then the navigation area' do
        navigation_item # Ensure associations are set up
        initial_nav_area_timestamp = navigation_area.updated_at
        initial_nav_item_timestamp = navigation_item.updated_at
        sleep 0.01

        Mobility.with_locale(I18n.default_locale) do
          page.update!(title: 'New Page Title')
        end

        # Page touching nav item requires touch: true on linkable association
        expect(navigation_item.reload.updated_at).to be > initial_nav_item_timestamp
        expect(navigation_area.reload.updated_at).to be > initial_nav_area_timestamp
      end
    end

    context 'when parent navigation item is updated' do
      let(:parent_item) do
        create(:better_together_navigation_item,
               navigation_area:,
               parent: nil,
               visible: true,
               privacy: 'public')
      end
      let(:child_item) do
        create(:better_together_navigation_item,
               navigation_area:,
               parent: parent_item,
               visible: true,
               privacy: 'public')
      end

      it 'touches the parent item which touches the navigation area' do
        child_item # Ensure it exists
        initial_timestamp = navigation_area.updated_at
        sleep 0.01

        child_item.update!(url: '/child-url')

        expect(parent_item.reload.updated_at).to be > initial_timestamp
        expect(navigation_area.reload.updated_at).to be > initial_timestamp
      end
    end
  end

  describe 'cache key invalidation scenarios' do
    it 'updates cache_key_with_version when navigation_area is touched' do
      # Create own item to avoid lock_version conflicts
      item = create(:better_together_navigation_item,
                    navigation_area:,
                    linkable: page,
                    title: 'Nav Item',
                    visible: true,
                    privacy: 'public',
                    protected: false)
      original_cache_key = navigation_area.cache_key_with_version
      sleep 0.01

      # Update without Mobility wrapper - let it use current locale
      item.title = 'New Title'
      item.save!

      expect(navigation_area.reload.cache_key_with_version).not_to eq(original_cache_key)
    end

    it 'updates cache_key_with_version when linked page is updated' do
      navigation_item # Ensure setup
      original_cache_key = navigation_area.cache_key_with_version
      Mobility.with_locale(I18n.default_locale) do
        page.update!(title: 'Updated Page Title')
      end

      page.update!(title: 'Updated Page Title')

      expect(navigation_area.reload.cache_key_with_version).not_to eq(original_cache_key)
    end

    it 'updates cache_key_with_version when new item is added' do
      original_cache_key = navigation_area.cache_key_with_version
      sleep 0.01

      create(:better_together_navigation_item, navigation_area:, visible: true, privacy: 'public')

      expect(navigation_area.reload.cache_key_with_version).not_to eq(original_cache_key)
    end

    it 'updates cache_key_with_version when item is destroyed' do
      navigation_item # Ensure it exists
      original_cache_key = navigation_area.cache_key_with_version
      sleep 0.01

      result = navigation_item.destroy
      expect(result).to be_truthy, "Destroy failed: #{navigation_item.errors.full_messages}"
      sleep 0.01 # Give time for after_commit callback

      expect(navigation_area.reload.cache_key_with_version).not_to eq(original_cache_key)
    end
  end
end
