# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe EventCategory do
    describe 'factory' do
      it 'creates a valid event category' do
        event_category = build(:event_category)
        expect(event_category).to be_valid
      end
    end

    describe 'inheritance' do
      it 'inherits from Category' do
        expect(described_class.superclass).to eq(Category)
      end

      it 'uses STI with type column' do
        event_category = create(:event_category)
        expect(event_category.type).to eq('BetterTogether::EventCategory')
      end

      it 'can be queried through Category' do
        event_category = create(:event_category)
        expect(Category.find(event_category.id)).to eq(event_category)
      end
    end

    describe 'associations' do
      it { is_expected.to have_many(:categorizations).dependent(:destroy) }
      it { is_expected.to have_many(:events).through(:categorizations) }
    end

    describe 'validations' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:type) }
    end

    describe 'translatable attributes' do
      it 'has translatable name' do
        event_category = create(:event_category, name: 'English Name')
        expect(event_category.name).to eq('English Name')
      end

      it 'has translatable description' do
        event_category = create(:event_category, description: 'Test Description')
        expect(event_category.description).to be_present
      end
    end

    describe '#as_category' do
      it 'returns instance as base Category class' do
        event_category = create(:event_category)
        as_category = event_category.as_category

        expect(as_category).to be_a(Category)
        expect(as_category.id).to eq(event_category.id)
      end
    end

    describe 'event categorization' do
      it 'can categorize events' do
        event_category = create(:event_category)
        event = create(:event)

        categorization = create(:categorization,
                                category: event_category,
                                categorizable: event)

        expect(event_category.events).to include(event)
        expect(event_category.categorizations).to include(categorization)
      end

      it 'allows multiple events in one category' do
        event_category = create(:event_category)
        event1 = create(:event)
        event2 = create(:event)

        create(:categorization, category: event_category, categorizable: event1)
        create(:categorization, category: event_category, categorizable: event2)

        expect(event_category.events.count).to eq(2)
        expect(event_category.events).to contain_exactly(event1, event2)
      end

      it 'removes categorizations when category is destroyed' do
        event_category = create(:event_category)
        event = create(:event)
        create(:categorization,
               category: event_category,
               categorizable: event)

        expect { event_category.destroy }.to change(Categorization, :count).by(-1)
      end
    end

    describe 'identifier behavior' do
      it 'generates unique identifiers' do
        cat1 = create(:event_category)
        cat2 = create(:event_category)

        expect(cat1.identifier).to be_present
        expect(cat2.identifier).to be_present
        expect(cat1.identifier).not_to eq(cat2.identifier)
      end
    end
  end
end
