# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Categorization do
    describe 'factory' do
      it 'creates a valid categorization' do
        categorization = build(:categorization)
        expect(categorization).to be_valid
      end

      it 'creates categorization with event and event_category' do
        categorization = create(:categorization,
                                category: create(:event_category),
                                categorizable: create(:event))
        expect(categorization.category).to be_an(EventCategory)
        expect(categorization.categorizable).to be_an(Event)
      end

      it 'creates categorization with page and category' do
        categorization = create(:categorization,
                                category: create(:category),
                                categorizable: create(:page))
        expect(categorization.category).to be_a(Category)
        expect(categorization.categorizable).to be_a(Page)
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:category) }
      it { is_expected.to belong_to(:categorizable) }

      it 'touches categorizable on save' do
        categorization = create(:categorization)
        categorizable = categorization.categorizable

        # The touch: true option means updating the categorization
        # will update the categorizable's updated_at
        expect { categorization.touch }.to(change { categorizable.reload.updated_at })
      end
    end

    describe 'polymorphic category' do
      it 'accepts Category as category' do
        category = create(:category)
        categorization = create(:categorization, category: category)

        expect(categorization.category).to eq(category)
        expect(categorization.category_type).to eq('BetterTogether::Category')
      end

      it 'accepts EventCategory as category' do
        event_category = create(:event_category)
        categorization = create(:categorization, category: event_category)

        expect(categorization.category).to be_a(EventCategory)
        # STI stores base class type in polymorphic associations
        expect(categorization.category_type).to eq('BetterTogether::Category')
      end
    end

    describe 'polymorphic categorizable' do
      it 'accepts Event as categorizable' do
        event = create(:event)
        categorization = create(:categorization, categorizable: event)

        expect(categorization.categorizable).to eq(event)
        expect(categorization.categorizable_type).to eq('BetterTogether::Event')
      end

      it 'accepts Page as categorizable' do
        page = create(:page)
        categorization = create(:categorization, categorizable: page)

        expect(categorization.categorizable).to eq(page)
        expect(categorization.categorizable_type).to eq('BetterTogether::Page')
      end
    end

    describe 'join table behavior' do
      it 'links category and categorizable' do
        category = create(:category)
        page = create(:page)
        categorization = create(:categorization,
                                category: category,
                                categorizable: page)

        expect(categorization.category).to eq(category)
        expect(categorization.categorizable).to eq(page)
      end

      it 'allows same categorizable in different categories' do
        page = create(:page)
        category1 = create(:category)
        category2 = create(:category)

        cat1 = create(:categorization, category: category1, categorizable: page)
        cat2 = create(:categorization, category: category2, categorizable: page)

        expect(cat1.categorizable).to eq(page)
        expect(cat2.categorizable).to eq(page)
        expect(cat1.category).not_to eq(cat2.category)
      end

      it 'allows same category for different categorizables' do
        category = create(:category)
        page1 = create(:page)
        page2 = create(:page)

        cat1 = create(:categorization, category: category, categorizable: page1)
        cat2 = create(:categorization, category: category, categorizable: page2)

        expect(cat1.category).to eq(category)
        expect(cat2.category).to eq(category)
        expect(cat1.categorizable).not_to eq(cat2.categorizable)
      end
    end
  end
end
