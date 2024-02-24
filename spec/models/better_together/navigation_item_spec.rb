# frozen_string_literal: true

# spec/models/better_together/navigation_item_spec.rb

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe NavigationItem, type: :model do # rubocop:todo Metrics/BlockLength
    subject(:navigation_item) { build(:better_together_navigation_item) }
    subject(:existing_navigation_item) { create(:better_together_navigation_item) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(navigation_item).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:navigation_area) }
      it { is_expected.to belong_to(:parent).class_name('NavigationItem').optional }
      it { is_expected.to have_many(:children).class_name('NavigationItem').dependent(:destroy) }
    end

    describe 'ActiveModel validations' do
      it { is_expected.to validate_presence_of(:title) }
      it { is_expected.to validate_length_of(:title).is_at_most(255) }
      # it { is_expected.to validate_inclusion_of(:visible).in_array([true, false]) }
      it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
      it { is_expected.to validate_inclusion_of(:item_type).in_array(%w[link dropdown separator]) }
      it { is_expected.to allow_value('http://example.com').for(:url) }
      it { is_expected.to allow_value('#').for(:url) }
      it { is_expected.to allow_value('').for(:url) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:title) }
      it { is_expected.to respond_to(:slug) }
      it { is_expected.to respond_to(:url) }
      it { is_expected.to respond_to(:icon) }
      it { is_expected.to respond_to(:position) }
      it { is_expected.to respond_to(:visible) }
      it { is_expected.to respond_to(:item_type) }
      it { is_expected.to respond_to(:protected) }
      it { is_expected.to respond_to(:linkable_type) }
      it { is_expected.to respond_to(:linkable_id) }
    end

    describe 'Scopes' do
      describe '.top_level' do
        it 'returns only top-level navigation items' do
          create(:better_together_navigation_item, parent: existing_navigation_item)
          expect(NavigationItem.top_level.count).to eq(1)
        end
      end

      describe '.visible' do
        it 'returns only visible navigation items' do
          create(:better_together_navigation_item, visible: true)
          create(:better_together_navigation_item, visible: false)
          expect(NavigationItem.visible.count).to eq(1)
        end
      end
    end

    describe 'Methods' do # rubocop:todo Metrics/BlockLength
      describe '#child?' do
        context 'when navigation item has a parent' do
          before { navigation_item.parent = create(:better_together_navigation_item) }

          it 'returns true' do
            expect(navigation_item.child?).to be true
          end
        end

        context 'when navigation item has no parent' do
          it 'returns false' do
            expect(navigation_item.child?).to be false
          end
        end
      end

      describe '#dropdown?' do
        context 'when item type is dropdown' do
          before { navigation_item.item_type = 'dropdown' }

          it 'returns true' do
            expect(navigation_item.dropdown?).to be true
          end
        end

        context 'when item type is not dropdown' do
          before { navigation_item.item_type = 'link' }

          it 'returns false' do
            expect(navigation_item.dropdown?).to be false
          end
        end
      end

      describe '#url' do
        context 'when linkable is present' do
          let(:linkable_page) { create(:better_together_page) }
          before { navigation_item.linkable = linkable_page }

          it 'returns the url of the linkable object' do
            expect(navigation_item.url).to eq(linkable_page.url)
          end
        end

        context 'when linkable is not present' do
          context 'and url is set' do
            before { navigation_item.url = 'http://example.com' }

            it 'returns the set url' do
              expect(navigation_item.url).to eq('http://example.com')
            end
          end

          context 'and url is not set' do
            before { navigation_item.url = nil }

            it 'returns default url (#)' do
              expect(navigation_item.url).to eq('#')
            end
          end
        end
      end
    end
  end
end
