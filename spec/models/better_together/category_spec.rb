# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Category do
    describe 'factory' do
      it 'creates a valid category' do
        category = build(:category)
        expect(category).to be_valid
      end

      it 'creates categories with custom icons' do
        category = create(:category, :with_custom_icon)
        expect(category.icon).to eq('fas fa-star')
      end
    end

    describe 'associations' do
      it { is_expected.to have_many(:categorizations).dependent(:destroy) }
      it { is_expected.to have_many(:pages).through(:categorizations) }
    end

    describe 'validations' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:type) }
    end

    describe 'translatable attributes' do
      it 'has translatable name' do
        category = create(:category, name: 'Test Category')
        expect(category.name).to eq('Test Category')
      end

      it 'has translatable description' do
        category = create(:category, description: 'Test Description')
        expect(category.description).to be_present
      end
    end

    describe '#as_category' do
      it 'returns self when already base class' do
        category = create(:category)
        expect(category.as_category).to eq(category)
      end

      it 'converts subclass to base Category' do
        event_category = create(:event_category)
        as_category = event_category.as_category

        expect(as_category).to be_a(described_class)
        expect(as_category.id).to eq(event_category.id)
      end
    end

    describe 'STI behavior' do
      it 'uses type column for STI' do
        category = create(:category)
        expect(category.type).to eq('BetterTogether::Category')
      end

      it 'supports subclasses like EventCategory' do
        event_category = create(:event_category)
        expect(event_category).to be_a(described_class)
        expect(event_category.type).to eq('BetterTogether::EventCategory')
      end
    end

    describe 'categorization' do
      it 'can categorize pages' do
        category = create(:category)
        page = create(:page)
        categorization = create(:categorization,
                                category: category,
                                categorizable: page)

        expect(category.pages).to include(page)
        expect(category.categorizations).to include(categorization)
      end

      it 'removes categorizations when destroyed' do
        category = create(:category)
        page = create(:page)
        create(:categorization, category: category, categorizable: page)

        expect { category.destroy }.to change(Categorization, :count).by(-1)
      end
    end

    describe 'identifier behavior' do
      it 'generates unique identifiers' do
        cat1 = create(:category)
        cat2 = create(:category)

        expect(cat1.identifier).to be_present
        expect(cat2.identifier).to be_present
        expect(cat1.identifier).not_to eq(cat2.identifier)
      end
    end

    describe 'icon attribute' do
      it 'has default icon value' do
        category = create(:category)
        expect(category.icon).to be_present
      end

      it 'stores custom icon value when provided' do
        category = create(:category, icon: 'fas fa-star')
        expect(category.icon).to eq('fas fa-star')
      end
    end
  end
end
