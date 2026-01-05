# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Factory Slug Uniqueness Verification' do
  describe 'creates multiple instances without slug collisions' do
    it 'creates 5 unique communities' do
      communities = create_list(:community, 5)
      slugs = communities.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(communities.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique platforms' do
      platforms = create_list(:platform, 5)
      slugs = platforms.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(platforms.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique agreements' do
      agreements = create_list(:agreement, 5)
      slugs = agreements.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(agreements.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique checklists' do
      checklists = create_list(:better_together_checklist, 5)
      slugs = checklists.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(checklists.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique pages' do
      pages = create_list(:page, 5)
      slugs = pages.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(pages.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique calendars' do
      calendars = create_list(:calendar, 5)
      slugs = calendars.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(calendars.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique wizards' do
      wizards = create_list(:wizard, 5)
      slugs = wizards.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(wizards.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique countries' do
      countries = create_list(:country, 5)
      slugs = countries.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(countries.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique regions' do
      regions = create_list(:region, 5)
      slugs = regions.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(regions.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique states' do
      states = create_list(:state, 5)
      slugs = states.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(states.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique continents' do
      continents = create_list(:continent, 5)
      slugs = continents.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(continents.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique settlements' do
      settlements = create_list(:settlement, 5)
      slugs = settlements.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(settlements.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique buildings' do
      buildings = create_list(:building, 5)
      slugs = buildings.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(buildings.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique navigation items' do
      navigation_items = create_list(:navigation_item, 5)
      slugs = navigation_items.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(navigation_items.all?(&:persisted?)).to be(true)
    end

    it 'creates 5 unique navigation areas' do
      navigation_areas = create_list(:navigation_area, 5)
      slugs = navigation_areas.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(navigation_areas.all?(&:persisted?)).to be(true)
    end
  end

  describe 'checklist items with unique labels' do
    it 'creates 5 unique checklist items' do
      checklist = create(:better_together_checklist)
      items = create_list(:better_together_checklist_item, 5, checklist: checklist)
      slugs = items.map(&:slug)

      expect(slugs.uniq.length).to eq(5), "Expected 5 unique slugs, got: #{slugs.inspect}"
      expect(items.all?(&:persisted?)).to be(true)
    end
  end
end
